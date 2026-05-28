#!/bin/bash

# After GenomicsDBImport succeeds...

# ============= JOINT GENOTYPING =============
echo "Running GenotypeGVCFs on GenomicsDB workspace..."

# Check if GenomicsDB workspace exists
if [ ! -d "$GENOMICSDB_DIR" ]; then
    echo "ERROR: GenomicsDB workspace not found: $GENOMICSDB_DIR"
    echo "Please run GenomicsDBImport first"
    exit 1
fi

# Check if interval file exists
if [ ! -f "$INTERVAL_BED" ]; then
    echo "ERROR: Interval file not found: $INTERVAL_BED"
    exit 1
fi

cp "$INTERVAL_BED" interval.bed

$GATK GenotypeGVCFs \
    -R "$REFGENOME" \
    -V "gendb://$GENOMICSDB_DIR" \
    -O "$FINAL_VCF" \
    -L interval.bed \
    --only-output-calls-starting-in-intervals \
    --use-new-qual-calculator \
    --annotation-group StandardAnnotation \
    --annotation-group AS_StandardAnnotation

# Check if GenotypeGVCFs succeeded
if [ $? -ne 0 ] || [ ! -f "$FINAL_VCF" ]; then
    echo "ERROR: GenotypeGVCFs failed"
    exit 1
fi

echo "Joint genotyping completed successfully!"
echo "Genotyping complete. Final VCF file: $FINAL_VCF"

## 2. Filtering SNPs and Indels

# 2.1. Train the GATK Recalibration Model: VariantRecalibrator

### SNP
echo "Training SNP recalibration model with multiple resources..."
$GATK VariantRecalibrator \
    -V "$FINAL_VCF" \
    -O "${OUTPUT_DIR}/snps.recal" \
    --tranches-file "${OUTPUT_DIR}/snps.tranches" \
    --output-model "${OUTPUT_DIR}/snps.model" \
    --resource:7g8_gb4,known=false,training=true,truth=true,prior=15.0 "$PF_CROSSES_FILE2" \
    --resource:hb3_dd2,known=false,training=true,truth=true,prior=15.0 "$PF_CROSSES_FILE3" \
    --resource:3d7_hb3,known=false,training=true,truth=true,prior=15.0 "$PF_CROSSES_FILE1" \
    -an QD -an FS -an SOR -an MQRankSum -an ReadPosRankSum -an MQ \
    -mode SNP \
    --trust-all-polymorphic

# Check if SNP recalibration succeeded
if [ $? -ne 0 ]; then
    echo "ERROR: SNP VariantRecalibrator failed"
    exit 1
fi

### INDELS
echo "Training INDEL recalibration model..."
$GATK VariantRecalibrator \
    -V "$FINAL_VCF" \
    -O "${OUTPUT_DIR}/indels.recal" \
    --tranches-file "${OUTPUT_DIR}/indels.tranches" \
    --output-model "${OUTPUT_DIR}/indels.model" \
    --resource:7g8_gb4,known=false,training=true,truth=true,prior=15.0 "$PF_CROSSES_FILE2" \
    --resource:hb3_dd2,known=false,training=true,truth=true,prior=15.0 "$PF_CROSSES_FILE3" \
    --resource:3d7_hb3,known=false,training=true,truth=true,prior=15.0 "$PF_CROSSES_FILE1" \
    -an QD -an FS -an SOR -an MQRankSum -an ReadPosRankSum -an MQ \
    -mode INDEL \
    --trust-all-polymorphic

# Check if INDEL recalibration succeeded
if [ $? -ne 0 ]; then
    echo "ERROR: INDEL VariantRecalibrator failed"
    exit 1
fi

# 2.2. Apply the recalibration model: ApplyRecalibration

### INDELS
echo "Applying VQSR for INDELs..."
$GATK ApplyVQSR \
    -V "$FINAL_VCF" \
    --recal-file "${OUTPUT_DIR}/indels.recal" \
    --tranches-file "${OUTPUT_DIR}/indels.tranches" \
    -mode INDEL \
    -O "${OUTPUT_DIR}/filtered_indels.vcf.gz" \
    --truth-sensitivity-filter-level 99 \
    --create-output-variant-index true

# Check if INDEL ApplyVQSR succeeded
if [ $? -ne 0 ] || [ ! -f "${OUTPUT_DIR}/filtered_indels.vcf.gz" ]; then
    echo "ERROR: INDEL ApplyVQSR failed"
    exit 1
fi

### SNP
echo "Applying VQSR for SNPs..."
$GATK ApplyVQSR \
    -V "${OUTPUT_DIR}/filtered_indels.vcf.gz" \
    --recal-file "${OUTPUT_DIR}/snps.recal" \
    --tranches-file "${OUTPUT_DIR}/snps.tranches" \
    -mode SNP \
    -O "$ApplyVQSR_VCF" \
    --truth-sensitivity-filter-level 99 \
    --create-output-variant-index true

# Check if SNP ApplyVQSR succeeded
if [ $? -eq 0 ] && [ -f "$ApplyVQSR_VCF" ]; then
    echo "Filtering and genotyping pipeline complete. Final filtered VCF: $ApplyVQSR_VCF"
else
    echo "ERROR: SNP ApplyVQSR failed"
    exit 1
fi
