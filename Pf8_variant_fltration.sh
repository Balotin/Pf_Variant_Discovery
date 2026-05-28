#!/bin/bash
: '
This process applies variant filtration to a VCF file using GATKs
VariantFiltration tool. It filters variants based on several criteria,
including VQSLOD value, region type (e.g., centromere, subtelomeric,
mitochondrion), and the presence of VQSLOD. It generates a filtered VCF
and its index, with multiple filtering steps, including invalidating
previous filters before applying new ones.
'

# Variant filtration
gatk VariantFiltration \
    -V "$ANNOTATED_WITH_REGIONS_VCF" \
    -O "$FILTERED_VCF" \
    --reference "$REFGENOME" \
    --filter-name "MissingVQSLOD" --filter-expression "!vc.hasAttribute('VQSLOD')" \
    --filter-name "Low_VQSLOD" --filter-expression "VQSLOD <= $variant_filtration_vqslod_threshold" \
    --filter-name "Centromere" --filter-expression "RegionType == 'Centromere'" \
    --filter-name "InternalHypervariable" --filter-expression "RegionType == 'InternalHypervariable'" \
    --filter-name "SubtelomericHypervariable" --filter-expression "RegionType == 'SubtelomericHypervariable'" \
    --filter-name "SubtelomericRepeat" --filter-expression "RegionType == 'SubtelomericRepeat'" \
    --filter-name "Apicoplast" --filter-expression "RegionType == 'Apicoplast'" \
    --filter-name "Mitochondrion" --filter-expression "RegionType == 'Mitochondrion'"
    
