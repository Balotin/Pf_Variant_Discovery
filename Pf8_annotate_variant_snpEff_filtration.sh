#!/bin/bash

# Annotate the Variants with SnpEff and add region/CDS annotations

# ============= CONFIGURATION =============
##if needed: pre-built SnpEff database manually reccording to add_genome_snpEff.sh

# ============= CREATE REGIONS FILE =============
echo "=== Creating BED region file ==="

# Check if REGIONS_BED exists
if [ ! -f "$REGIONS_BED" ]; then
    echo "ERROR: REGIONS_BED file not found: $REGIONS_BED"
    exit 1
fi

# Copy the regions file
cp "$REGIONS_BED" regions-20130225-plus-api-mt.bed

# Add Apicoplast and Mitochondrion regions
echo -e "Pf3D7_API_v3\t0\t34250\tApicoplast" >> regions-20130225-plus-api-mt.bed
echo -e "Pf3D7_MIT_v3\t0\t5967\tMitochondrion" >> regions-20130225-plus-api-mt.bed

# Create core regions file
grep -F "Core" < regions-20130225-plus-api-mt.bed > regions-20130225.core.bed

# Compress the full regions file (skip if already exists)
if [ ! -f regions-20130225-plus-api-mt.bed.gz ]; then
    gzip regions-20130225-plus-api-mt.bed
fi

echo "Regions BED files created"

# ============= CREATE CDS FILE =============
echo "=== Creating CDS GFF file ==="

# Check if GFF file exists
if [ ! -f "$GFF_PF7" ]; then
    echo "ERROR: GFF file not found: $GFF_PF7"
    exit 1
fi

# Convert GFF to 4-column BED-like format: CHROM, START, END, CDS_ID
# Extract CDS lines and reformat
# Extract CDS lines and convert to BED-like format with CDS ID
grep -P "\tCDS\t" "$GFF_PF7" | \
    awk -F'\t' '{
        # Extract the gene identifier
        if (match($9, /Parent=([^;]+)/)) {
            cds_id = substr($9, RSTART+7, RLENGTH-7)
        } else if (match($9, /ID=([^;]+)/)) {
            cds_id = substr($9, RSTART+3, RLENGTH-3)
        } else {
            cds_id = "CDS_" $1 "_" $4 "_" $5
        }
        # Remove any version suffix (e.g., .1) if present
        gsub(/\.[0-9]+$/, "", cds_id)
        print $1 "\t" $4 "\t" $5 "\t" cds_id
    }' | \
    sort -k1,1 -k2,2n | \
    gzip > cds_regions.bed.gz


# ============= CREATE HEADER FILE =============
echo "=== Creating custom region header ==="

cat > regions_header.txt << 'EOF'
##INFO=<ID=CDS,Number=1,Type=String,Description="CDS identifier from GFF annotation">
##INFO=<ID=RegionType,Number=1,Type=String,Description="The type of genome region within which the variant is found. SubtelomericRepeat: repetitive regions at the ends of the chromosomes. SubtelomericHypervariable: subtelomeric region of poor conservation between the 3D7 reference genome and other samples. InternalHypervariable: chromosome-internal region of poor conservation between the 3D7 reference genome and other samples. Centromere: start and end coordinates of the centromere genome annotation. Apicoplast: apicoplast. Mitochondrion: mitochondrion. Core: everything else.">
##FILTER=<ID=Apicoplast,Description="Variant in apicoplast region">
##FILTER=<ID=Centromere,Description="Variant in centromeric region">
##FILTER=<ID=Core,Description="Variant in core genomic region">
##FILTER=<ID=InternalHypervariable,Description="Variant in internal hypervariable region">
##FILTER=<ID=Mitochondrion,Description="Variant in mitochondrial region">
##FILTER=<ID=SubtelomericHypervariable,Description="Variant in subtelomeric hypervariable region">
##FILTER=<ID=SubtelomericRepeat,Description="Variant in subtelomeric repeat region">
EOF

echo "Header file created"



# ============= RUN ANNOTATION =============
echo "=== Annotating with SnpEff and bcftools ==="

# Run SnpEff and pipe through bcftools annotations
snpEff \
    "$SNPEFF_DB" \
    -no-downstream -no-upstream -onlyProtein \
    "$ApplyVQSR_VCF" \
    | \
bcftools annotate \
    -a cds_regions.bed.gz \
    -c CHROM,FROM,TO,CDS \
    -h regions_header.txt \
    | \
bcftools annotate \
    -a regions-20130225-plus-api-mt.bed.gz \
    -c CHROM,FROM,TO,RegionType \
    | \
sed -r 's/VQSLOD=([-+]?)inf[^;]*(;?.*)$/VQSLOD=\1Infinity\2/' \
    | \
bgzip > "$ANNOTATED_WITH_REGIONS_VCF"

# Check if annotation succeeded
if [ $? -eq 0 ] && [ -f "$ANNOTATED_WITH_REGIONS_VCF" ]; then
    echo "=== Annotation Complete ==="
    
    # Index the annotated VCF
    echo "=== Indexing annotated VCF ==="
    tabix -p vcf "$ANNOTATED_WITH_REGIONS_VCF"
    
    echo "Output file: $ANNOTATED_WITH_REGIONS_VCF"
    echo "Index file: ${ANNOTATED_WITH_REGIONS_VCF}.tbi"
else
    echo "ERROR: Annotation failed"
    exit 1
fi
