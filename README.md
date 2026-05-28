# Plasmodium falciparum Variant Calling Pipeline

## Overview

This pipeline performs SNP and INDEL variant calling for *Plasmodium falciparum* genomes, following the standardized approach developed for the MalariaGEN Pf9 project. The workflow processes raw sequencing reads through quality control, alignment, variant discovery, filtering, and annotation to produce high-confidence variant calls.

**Pipeline version:** Pf8  
**Target species:** *Plasmodium falciparum*  
**Based on:** MalariaGEN Pf9 variant calling standard

---

## Pipeline Architecture
Pf8_PfVariantsDiscovery_main.sh (Master script)
├── A. Reference Preparation (manual)
├── B. SNPEff Database Creation (one-time setup)
└── Main Pipeline Steps (automated)
├── 1. Read Filtering & Trimming
├── 2. Read Mapping & Duplicate Removal
├── 3. Base Quality Recalibration
├── 4. Mapping Statistics
├── 5. Variant Calling (HaplotypeCaller)
├── 6. Variant Quality Recalibration
├── 7. Variant Annotation
└── 8. Variant Filtering

---
## TOBEMODIFIED
This pipeline was wrote on ubuntu 22.04.5 and is working on a conda environment. 
modify all the field in the "Pf8_PfVariantsDiscovery_main.sh" mentioned as "TOBEMODIFIED" according to your need

---
## A Create a new conda environment with required dependencies
```bash
conda create -n Pf_Variants_Discovery -c bioconda -c conda-forge \
    bwa \
    samtools \
    gatk4 \
    snpeff \
    fastqc \
    trimmomatic \
    bcftools \
    bedtools \
    picard \
    tabix \
    parallel \
    multiqc \
    python=3.9

# Activate the environment
conda activate pf_variant_calling

# Verify installation
echo "=== Verifying installations ==="
bwa 2>&1 | head -1
samtools --version | head -1
gatk --version
bcftools --version | head -1
snpeff -version 2>&1 | head -1


# Always activate the environment first
conda activate Pf_Variants_Discovery
```

## B. Reference Genome Preparation

Before running the pipeline, prepare the reference genome index files:

```bash
# Navigate to reference directory
cd ./data/Reference

# Index with BWA (for read alignment)
bwa index Pfalciparum.genome.fasta

# Create samtools FASTA index (for random access)
samtools faidx Pfalciparum.genome.fasta

# Create GATK sequence dictionary (for GATK tools)
gatk CreateSequenceDictionary -R Pfalciparum.genome.fasta -O Pfalciparum.genome.dict

```

## C. Create Custom SNPEff Database
To annotate variants specifically for your reference genome:
```bash
./scripts/create_custom_database_snpEff.sh
```
This script builds a custom SNPEff database matching your reference genome version. See create_custom_database_snpEff.sh for detailed instructions.

## C. Running the Main Pipeline
```bash
BASEDIR="/path/to/pipeline/directory"
cd $BASEDIR

```
## Pipeline Steps in Detail
#### 1. Read Filtering and Trimming (Pf8_filtering_and_trimming.sh)

Purpose: Quality control and removal of low-quality bases and adapters

Operations:

    Filter raw reads by quality scores

    Trim adapters and low-quality ends

    Remove reads shorter than minimum length

Input: Raw FASTQ files
Output: Trimmed FASTQ files

#### 2. Read Mapping and Duplicate Removal (Pf8_map_fastq_file_and_dedup_3D7_V54.sh)

Purpose: Align trimmed reads to the reference genome

Operations:

    Map reads using BWA-MEM

    Sort aligned reads by coordinate

    Mark and remove PCR duplicates

Input: Trimmed FASTQ files
Output: Sorted, deduplicated BAM files

#### 3. Base Quality Recalibration (Pf8_BaseRecalibration_bam_file.sh)

Purpose: Correct systematic sequencing errors using known variant sites

Operations:

    Identify covariates affecting base quality

    Apply recalibration using Pf7 known sites as reference

Input: Deduplicated BAM files
Output: Recalibrated BAM files

#### 4. Mapping Statistics (Pf8_bam_statistics.sh & Pf8_summary_bam_stats.sh)

Purpose: Generate comprehensive mapping metrics

Operations:

    Calculate mapping rates, coverage, and depth

    Aggregate statistics across all samples

    Generate summary CSV reports

Input: Recalibrated BAM files
Output: Individual stats files + summary_bamstats.csv

#### 5. Variant Calling (Pf8_calling_SNP_Indels.sh)

Purpose: Discover SNPs and INDELs from aligned reads

Operations:

    Run GATK4 HaplotypeCaller per sample

    Generate gVCF files for joint genotyping

Input: Recalibrated BAM files
Output: gVCF files (per sample)

#### 6. Variant Quality Recalibration (Pf8_genotype_recalibration.sh)

Purpose: Apply machine learning to filter false positives

Operations:

    Joint genotyping across all samples

    Recalibrate variant quality scores using Pf training resources

    Apply VQSR (Variant Quality Score Recalibration)

Input: Individual gVCF files
Output: Recalibrated VCF files

#### 7. Variant Annotation (Pf8_annotate_variant_snpEff_filtration.sh)

Purpose: Add functional annotations to variants

Operations:

    Annotate with custom SNPEff database

    Add variant consequences (missense, synonymous, etc.)

    Add population frequencies and other metadata

Input: Recalibrated VCF files
Output: Annotated VCF files

#### 8. Variant Filtering (Pf8_variant_filtration.sh)

Purpose: Apply final hard filters to produce high-confidence variant set

Operations:

    Filter by quality metrics (QD, FS, MQ, etc.)

    Apply depth and allele frequency thresholds

    Generate final filtered VCF

Input: Annotated VCF files
Output: Final filtered VCF files 

## Dependencies

Required software (ensure these are in your PATH):

    BWA (≥0.7.17) - Read alignment

    SAMtools (≥1.9) - BAM manipulation

    GATK4 (≥4.2.0) - Variant calling and recalibration

    SNPEff (≥5.0) - Variant annotation

    FastQC (≥0.11.9) - Read quality (optional)

    Trimmomatic (≥0.39) - Read trimming

    bgzip / tabix - VCF compression/indexing

