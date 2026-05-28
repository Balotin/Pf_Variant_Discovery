#!/bin/bash

: '
This script performs variant calling and genotyping for multiple samples using GATK and BCFtools.
The script includes generating alignment metrics, identifying callable loci, calling variants, combining gVCFs,
and performing joint genotyping.
'

# ============= START PIPELINE =============
# Touch checkpoint files (now variables are defined)
touch "$GVCF_CHECKPOINT" "$VCF_CHECKPOINT" "$FILTERED_VCF_CHECKPOINT"

# Call variants using HaplotypeCaller
for BAM_FILE in "$MAPDIR"/*_sorted_dedup_bqsr.bam; do
    # Check if any BAM files exist (first iteration only)
    if [ ! -f "$BAM_FILE" ] && [ "$BAM_FILE" = "$MAPDIR/*_sorted_dedup_bqsr.bam" ]; then
        echo "No BAM files found in $MAPDIR"
        exit 1
    fi
    
    SAMPLE_NAME=$(basename "$BAM_FILE" _sorted_dedup_bqsr.bam)
    gvcf_file="${GVCF_DIR}/${SAMPLE_NAME}.g.vcf.gz"
    gatk_file="${GVCF_DIR}/${SAMPLE_NAME}_gatk.bam"
    
    # Check if this sample has already been processed
    if [ -f "$GVCF_CHECKPOINT" ] && grep -q "^${SAMPLE_NAME}$" "$GVCF_CHECKPOINT"; then
        echo "Sample $SAMPLE_NAME already processed. Skipping..."
        continue
    fi
    
    # Check if output file already exists
    if [ -f "$gvcf_file" ]; then
        echo "Output file $gvcf_file already exists. Logging $SAMPLE_NAME and skipping..."
        echo "$SAMPLE_NAME" >> "$GVCF_CHECKPOINT"
        continue
    fi

    echo "Calling variants for $SAMPLE_NAME..."

    # Define Smith-Waterman parameters for Pf8 approach
    SW_OPTS="--smith-waterman-dangling-end-gap-extend-penalty -6 \
            --smith-waterman-dangling-end-gap-open-penalty -110 \
            --smith-waterman-dangling-end-match-value 25 \
            --smith-waterman-dangling-end-mismatch-penalty -50 \
            --smith-waterman-haplotype-to-reference-gap-extend-penalty -6 \
            --smith-waterman-haplotype-to-reference-gap-open-penalty -110 \
            --smith-waterman-haplotype-to-reference-match-value 25 \
            --smith-waterman-haplotype-to-reference-mismatch-penalty -50 \
            --smith-waterman-read-to-haplotype-gap-extend-penalty -5 \
            --smith-waterman-read-to-haplotype-gap-open-penalty -30 \
            --smith-waterman-read-to-haplotype-match-value 10 \
            --smith-waterman-read-to-haplotype-mismatch-penalty -15"

    cp "$INTERVAL_BED" interval.bed
    # Run HaplotypeCaller 
    $GATK HaplotypeCaller \
        -R "$REFGENOME" \
        -I "$BAM_FILE" \
        -O "$gvcf_file" \
        -ERC GVCF \
        -L interval.bed \
        --native-pair-hmm-threads "$threads" \
        --bamout "$gatk_file" \
        -contamination "$contamination" \
        --create-output-variant-index true \
        ${SW_OPTS}

    # Check if GATK succeeded
    if [ $? -eq 0 ] && [ -f "$gvcf_file" ]; then
        echo "Successfully processed $SAMPLE_NAME"
        echo "$SAMPLE_NAME" >> "$GVCF_CHECKPOINT"
    else
        echo "ERROR: HaplotypeCaller failed for $SAMPLE_NAME"
        exit 1
    fi
done

# Generate the sample map file for GenomicsDBImport
echo "Generating map file for GVCFs in: $GVCF_DIR"
MAP_FILE="$GVCF_MAP_DIR/sample_name_map.gvcf_map"

# Clear/create the map file
> "$MAP_FILE"

# Count GVCF files found
gvcf_count=0

# Loop through all GVCF files in the directory
for gvcf in "$GVCF_DIR"/*.g.vcf.gz; do
    if [[ -f "$gvcf" ]]; then
        SAMPLE_ID=$(basename "$gvcf" .g.vcf.gz)
        VCF_FILE=$(realpath "$gvcf")
        echo -e "$SAMPLE_ID\t$VCF_FILE" >> "$MAP_FILE"
        echo "Added: $SAMPLE_ID -> $VCF_FILE"
        ((gvcf_count++))
    fi
done

# Check if any GVCF files were found
if [ $gvcf_count -eq 0 ]; then
    echo "ERROR: No GVCF files found in $GVCF_DIR"
    exit 1
fi

echo "GVCF map file generated successfully: $MAP_FILE ($gvcf_count samples)"

# Import sample GVCFs into GenomicsDB before joint genotyping
# Or add to your script before GenomicsDBImport:
if [ -d "$GENOMICSDB_DIR" ]; then
    echo "Removing existing GenomicsDB workspace: $GENOMICSDB_DIR"
    rm -rf "$GENOMICSDB_DIR"
fi

TMP_DIR="./tmp_genomicsdb_$$"
mkdir -p "$TMP_DIR"
echo "Using temporary directory: $TMP_DIR"
echo "Starting GenomicsDBImport..."

# Enable strict error checking for this critical step
cp "$INTERVAL_BED" interval.bed
set -e
$GATK GenomicsDBImport \
    --genomicsdb-workspace-path "$GENOMICSDB_DIR" \
    --sample-name-map "$MAP_FILE" \
    -L interval.bed \
    --reader-threads "$threads" \
    --batch-size "$batch_size" \
    --tmp-dir "$TMP_DIR" \
    ${interval_padding:+ -ip "$interval_padding"}  # Only add if >0

# Capture exit status
GENOMICSDB_EXIT=$?
set +e  # Disable strict error checking

# Check if GenomicsDBImport succeeded
if [ $GENOMICSDB_EXIT -eq 0 ]; then
    echo "GenomicsDBImport completed successfully"
    # Clean up temporary directory
    rm -rf "$TMP_DIR"
    echo "Temporary directory removed"
else
    echo "ERROR: GenomicsDBImport failed with exit code $GENOMICSDB_EXIT"
    echo "Temporary files preserved in: $TMP_DIR"
    exit 1
fi

echo "Variant calling pipeline completed successfully!"
