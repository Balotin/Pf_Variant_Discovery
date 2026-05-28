#!/bin/bash
: '
This script performs base recalibration and apply base recalibration on bam files.
Steps:
1. BaseRecalibrator - creates recalibration table
2. ApplyBQSR - applies recalibration to BAM
3. Handles GATK NullPointerException bug for problematic samples
'

## Ensure necessary environment variables are set
if [ -z "$REFGENOME" ] || [ -z "$KNOWN_SITES" ] || [ -z "$MAPDIR" ] || [ -z "$SAMPLE_LIST" ] || [ -z "$bqsr_checkpoint_file" ] || [ -z "$GATK" ]; then
    echo "One or more required environment variables are not set."
    echo "Required: REFGENOME, KNOWN_SITES, MAPDIR, SAMPLE_LIST, bqsr_checkpoint_file, GATK"
    exit 1
fi

## Check if reference genome exists
if [ ! -f "$REFGENOME" ]; then
    echo "Reference genome file not found: $REFGENOME"
    exit 1
fi

## Check if known sites VCF exists
if [ ! -f "$KNOWN_SITES" ]; then
    echo "Known sites file not found: $KNOWN_SITES"
    exit 1
fi

## Check if GATK is available
if ! command -v "$GATK" &> /dev/null; then
    echo "GATK not found: $GATK"
    exit 1
fi

## Check if map directory exists
if [ ! -d "$MAPDIR" ]; then
    echo "MAPDIR directory not found: $MAPDIR"
    exit 1
fi

## Check if sample list exists
if [ ! -f "$SAMPLE_LIST" ]; then
    echo "Sample list file not found: $SAMPLE_LIST"
    exit 1
fi

# Create checkpoint file if it doesn't exist
touch "$bqsr_checkpoint_file"

# Create a file to track samples with the NullPointerException fix
NASTY_FIX_FILE="${MAPDIR}/nasty-fix-applied.txt"
touch "$NASTY_FIX_FILE"

############ Process each sample from SAMPLE_LIST #############################################
while IFS= read -r sample; do

    # Remove any trailing carriage return characters
    sample=$(echo "$sample" | tr -d '\r')
    
    # Skip empty lines
    if [ -z "$sample" ]; then
        continue
    fi

    sample_name=$(basename "$sample")
    dedup_bam_file="${MAPDIR}/${sample_name}_sorted_dedup.bam"
    gatk_recalibration_report="${MAPDIR}/${sample_name}_bqsr.table"
    bqsr_bam_file="${MAPDIR}/${sample_name}_sorted_dedup_bqsr.bam"
    apply_bqsr_log="${MAPDIR}/${sample_name}_applyBQSR.err"

    echo "Processing $sample_name..."

    # Check if input BAM exists
    if [ ! -f "$dedup_bam_file" ]; then
        echo "ERROR: Deduplicated BAM file not found for $sample_name: $dedup_bam_file"
        exit 1
    fi

    # Check if the sample has already been processed
    if grep -q "^${sample_name}$" "$bqsr_checkpoint_file"; then
        echo "Sample $sample_name already processed for BQSR. Skipping..."
        continue
    fi

    # ===== STEP 1: BaseRecalibrator (Create recalibration model/table) =====
    if [ ! -f "$gatk_recalibration_report" ]; then
        echo "Running BaseRecalibrator for $sample_name..."
        
        $GATK BaseRecalibrator \
            -R "$REFGENOME" \
            -I "$dedup_bam_file" \
            --known-sites "$KNOWN_SITES" \
            -O "$gatk_recalibration_report" || {
                echo "ERROR: BaseRecalibrator failed for $sample_name"
                exit 1
            }
        
        echo "BaseRecalibrator completed for $sample_name"
    else
        echo "Recalibration table already exists for $sample_name. Skipping BaseRecalibrator..."
    fi

    # ===== STEP 2: ApplyBQSR (Apply recalibration to BAM) =====
    # Note: There's a known GATK bug where ApplyBQSR fails with NullPointerException for some samples
    # The workaround is to copy the original BAM if this occurs
    
    if [ ! -f "$bqsr_bam_file" ]; then
        echo "Running ApplyBQSR for $sample_name..."
        
        # Run ApplyBQSR and capture stderr to log file
        $GATK ApplyBQSR \
            -R "$REFGENOME" \
            -I "$dedup_bam_file" \
            -O "$bqsr_bam_file" \
            --create-output-bam-index \
            --bqsr-recal-file "$gatk_recalibration_report" 2> "$apply_bqsr_log"
        
        APPLY_BQSR_EXIT=$?
        
        # Check if ApplyBQSR succeeded
        if [ $APPLY_BQSR_EXIT -eq 0 ] && [ -f "$bqsr_bam_file" ]; then
            echo "ApplyBQSR completed successfully for $sample_name"
            
        # Check for the known NullPointerException bug
        elif grep -q "NullPointerException" "$apply_bqsr_log"; then
            echo "WARNING: Detected NullPointerException bug for $sample_name. Applying workaround..."
            echo "$sample_name" >> "$NASTY_FIX_FILE"
            
            # Workaround: copy the original BAM as the BQSR BAM
            cp "$dedup_bam_file" "$bqsr_bam_file"
            
            # Also copy the index if it exists
            if [ -f "${dedup_bam_file}.bai" ]; then
                cp "${dedup_bam_file}.bai" "${bqsr_bam_file}.bai"
            fi
            
            echo "Workaround applied for $sample_name"
            
        else
            echo "ERROR: ApplyBQSR failed for $sample_name with exit code $APPLY_BQSR_EXIT"
            echo "Check log file: $apply_bqsr_log"
            exit 1
        fi
    else
        echo "BQSR BAM already exists for $sample_name. Skipping ApplyBQSR..."
    fi

    # ===== STEP 3: Verify output BAM =====
    if [ -f "$bqsr_bam_file" ]; then
        # Basic validation
        if samtools quickcheck "$bqsr_bam_file" 2>/dev/null; then
            echo "✓ BQSR BAM validation passed for $sample_name"
            
            # Log successful completion
            echo "$sample_name" >> "$bqsr_checkpoint_file"
            echo "Completed processing for $sample_name"
        else
            echo "ERROR: BQSR BAM validation failed for $sample_name"
            exit 1
        fi
    else
        echo "ERROR: BQSR BAM file not created for $sample_name"
        exit 1
    fi
    
    echo "----------------------------------------"

done < "$SAMPLE_LIST"

echo "All samples processed successfully for BQSR!"
echo "Samples with NullPointerException workaround:"
cat "$NASTY_FIX_FILE"