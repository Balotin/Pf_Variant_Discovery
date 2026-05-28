#!/bin/bash

### TOBECHANGE
#1. SAMPLE_LIST="$BASEDIR/data/sample_list_AF1.txt" 
#2. AWREADS="$BASEDIR/data/reads" : put the raw reads in this file
#3. cahnge threads=8 and batch_size=50 depending on your computer/cluster and number of samples
#3. SNPEFF_DB="Pf8_54_custom_2020_MalariaGen"

### ENVIRONMENT VARIABLES ###
# Define paths to tools and directories
FASTQC="fastqc"
TRIMMOMATIC="trimmomatic"
BWA="bwa"
SAMTOOLS="samtools"
PICARD="picard"
GATK="gatk"
BCFTOOLS="bcftools"
DELLY="delly"

SNPEFF_DB="Pf8_54_custom_2020_MalariaGen"
BASEDIR="."
QUALDIR="$BASEDIR/quality_check"
TRIMDIR="$BASEDIR/trimmed_reads"
MAPDIR="$BASEDIR/mapped_reads"
OUTPUT_DIR="$BASEDIR/output_vcf"
VCF_SNP_INDELS="$OUTPUT_DIR/snp_indels"
VCF_CNV_SV="$OUTPUT_DIR/cnv_sv"
GVCF_DIR="$VCF_SNP_INDELS/gvcfs"
GVCF_MAP_DIR="$VCF_SNP_INDELS/gvcfs_maps"
GENOMICSDB_DIR="$VCF_SNP_INDELS/genomicsdb_output"
BAM_STATS="$MAPDIR/samtools_files"

DELLY_BCF="$VCF_CNV_SV/delly_bcf"
DELLY_OUT="$VCF_CNV_SV/delly_output"

# Define paths to data files
PF_CROSSES_FILE1="$BASEDIR/data/Pf_crosses/3d7_hb3.combined.final.vcf.gz"
PF_CROSSES_FILE2="$BASEDIR/data/Pf_crosses/7g8_gb4.combined.final.vcf.gz"
PF_CROSSES_FILE3="$BASEDIR/data/Pf_crosses/hb3_dd2.combined.final.vcf.gz"

PF_CORE_GENOME_MIL16="$BASEDIR/data/Useful_files/core_genome_Mil16.bed"
REGIONS_BED="$BASEDIR/data/Useful_files/regions-20130225_onebased.bed"
SAMPLE_LIST="$BASEDIR/data/sample_list.txt"
GVCF_SAMPLE_LIST="$BASEDIR/data/sample_list.txt"
REFGENOME_DIR="$BASEDIR/data/Reference"
REFGENOME="$BASEDIR/data/Reference/Pfalciparum.genome.fasta"

KNOWN_SITES="$BASEDIR/data/Useful_files/KnownSites_Pf3D7_AllChr_v3_PASS_only.pf7.vcf.gz"
GFF_PF7="$BASEDIR/data/Reference/Pfalciparum_replace_Pf3D7_MIT_v3_with_Pf_M76611.gff"
DICT="$BASEDIR/data/Reference/Pfalciparum.genome.dict"
RAWREADS="$BASEDIR/data/reads"
Adapters="$BASEDIR/data/Adaptators_seq/TruSeq3-PE.fa"
INTERVAL_BED="$BASEDIR/data/Useful_files/pf7.10kb.intervals.txt"

#Define output files
COMBINED_GVCF="$GVCF_DIR/combined.g.vcf.gz"
FINAL_VCF="$VCF_SNP_INDELS/final_variants.vcf.gz"
ApplyVQSR_VCF="$VCF_SNP_INDELS/AplyVQSR_variants.vcf.gz"
ANNOTATED_WITH_REGIONS_VCF="$VCF_SNP_INDELS/annotated_with_regions.vcf.gz"
FILTERED_VCF="$VCF_SNP_INDELS/final_filtered_variants.vcf.gz"

# Define the parameter as on Pf8
threads=10
batch_size=50
interval_padding=500
contamination=0
variant_filtration_vqslod_threshold=2.0



# Ensure required directories exist before running pipeline
mkdir -p "$TRIMDIR" "$MAPDIR" "$GVCF_DIR" "$OUTPUT_DIR" "$DELLY_BCF" "$DELLY_OUT" "$QUALDIR" "$VCF_SNP_INDELS" "$VCF_CNV_SV" "$GVCF_MAP_DIR" "$GENOMICSDB_DIR" "$BAM_STATS"

# Checkpoints
qc_checkpoint_file="$TRIMDIR/processed_filtered_samples.log"
map_checkpoint_file="$MAPDIR/processed_mapped_samples.log"
map_checkpoint_file_hb3="$MAPDIR/processed_mapped_samples_hb3.log"
map_checkpoint_file_dd2="$MAPDIR/processed_mapped_samples_dd2.log"
bqsr_checkpoint_file="$MAPDIR/processed_bqsr_checkpoint_file.log"

# Create checkpoint files for various steps
GVCF_CHECKPOINT="$VCF_SNP_INDELS/gvcf_checkpoint.log"
VCF_CHECKPOINT="$VCF_SNP_INDELS/vcf_checkpoint.log"
FILTERED_VCF_CHECKPOINT="$VCF_SNP_INDELS/filtered_vcf_checkpoint.log"
DELLY_BCF_CHECKPOINT="$DELLY_BCF/delly_bcf_checkpoint.log"
DELLY_GENOTYPED_CHECKPOINT="$VCF_CNV_SV/delly_genotyped_checkpoint.log"

touch "$qc_checkpoint_file"
touch "$map_checkpoint_file" 
touch "$bqsr_checkpoint_file"

# Export for sub-scripts
export FASTQC TRIMMOMATIC BWA SAMTOOLS PICARD GATK BCFTOOLS DELLY
export QUALDIR TRIMDIR MAPDIR SAMPLE_LIST REFGENOME RAWREADS Adapters threads batch_size ANNOTATED_ALL_VCF ANNOTATED_WITH_REGIONS_VCF contamination GVCF_MAP_DIR KNOWN_SITES BAM_STATS
export GVCF_DIR OUTPUT_DIR DELLY_BCF DELLY_OUT PF_CROSSES_FILE1 PF_CROSSES_FILE2 PF_CROSSES_FILE3 PF_CORE_GENOME_MIL16 REGIONS_BED ANNOTATED_CORE_VCF VCF_SNP_INDELS VCF_CNV_SV  GENOMICSDB_DIR interval_padding
export qc_checkpoint_file map_checkpoint_file GVCF_CHECKPOINT VCF_CHECKPOINT FILTERED_VCF_CHECKPOINT FILTERED_VCF map_checkpoint_file_hb3 INTERVAL_BED REFGENOME_DIR GFF_PF7 variant_filtration_vqslod_threshold
export DELLY_BCF_CHECKPOINT DELLY_GENOTYPED_CHECKPOINT SNPEFF_DB GFF GVCF_SAMPLE_LIST COMBINED_GVCF FINAL_VCF map_checkpoint_file_dd2 REFGENOME_HB3 REFGENOME_DD2 bqsr_checkpoint_file ApplyVQSR_VCF

#1. Runing base on MalariaGen Pf8 pipeline
#./Pf8_filtering_and_trimming.sh
#./Pf8_map_fastq_file_and_dedup_3D7_V54.sh
#./Pf8_BaseRecalibration_bam_file.sh
#./Pf8_bam_statistics.sh
#./Pf8_calling_SNP_Indels.sh
#./Pf8_genotype_recalibration.sh
./Pf8_annotate_variant_snpEff_filtration.sh
./Pf8_variant_fltration.sh


#2. Optional steps (uncomment when ready)
# ./calling_deletion_delly.sh
# ./calling_all_delly.sh
