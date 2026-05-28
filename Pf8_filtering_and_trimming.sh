#!/bin/bash

: '
This script performs quality control and filtering of raw reads, followed by trimming.
'

# Process each sample from SAMPLE_LIST
while read sample; do
    r1="${RAWREADS}/${sample}_R1_001.fastq.gz"
    r2="${RAWREADS}/${sample}_R2_001.fastq.gz"
    sample_name=$(basename $sample)
    
    # Check if the sample has already been processed
    if grep -q "^${sample_name}$" "$qc_checkpoint_file"; then
        echo "Sample $sample_name already processed for QC and filtering. Skipping..."
        continue
    fi

    echo "Processing sample: $sample_name"
    : '
    # Step 1: Quality control with FastQC (before trimming)
    if [ ! -f "$QUALDIR/${sample_name}_1_fastqc.html" ] || [ ! -f "$QUALDIR/${sample_name}_2_fastqc.html" ]; then
        echo "Running FastQC (before trimming) for $sample_name..."
        $FASTQC -o "$QUALDIR" -t $threads "$r1" "$r2"
    else
        echo "FastQC (before trimming) already done for $sample_name. Skipping..." 
    fi
    '
    # Step 2: Trimming with Trimmomatic
    trimmed_r1="${TRIMDIR}/${sample_name}_1_trimmed.fastq.gz"
    trimmed_r2="${TRIMDIR}/${sample_name}_2_trimmed.fastq.gz"
    trimmomatic_log="${TRIMDIR}/${sample_name}_trimmomatic.log"
    
    if [ ! -f "$trimmed_r1" ] || [ ! -f "$trimmed_r2" ]; then
        echo "Trimming reads for $sample_name..."
        $TRIMMOMATIC PE -threads $threads \
            -phred33 \
            "$r1" "$r2" \
            "$trimmed_r1" "${TRIMDIR}/${sample_name}_1_unpaired.fastq.gz" \
            "$trimmed_r2" "${TRIMDIR}/${sample_name}_2_unpaired.fastq.gz" \
            ILLUMINACLIP:"$Adapters":2:30:10 \
            LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36 \
            > $trimmomatic_log 2>&1
    else
        echo "Trimming already done for $sample_name. Skipping..."
    fi
    : '
    # Step 3: Quality control with FastQC (after trimming)
    if [ ! -f "$QUALDIR/${sample_name}_1_trimmed_fastqc.html" ] || [ ! -f "$QUALDIR/${sample_name}_2_trimmed_fastqc.html" ]; then
        echo "Running FastQC (after trimming) for $sample_name..."
        $FASTQC -o "$QUALDIR" -t $threads "$trimmed_r1" "$trimmed_r2"
    else
        echo "FastQC (after trimming) already done for $sample_name. Skipping..."
    fi
    '
    # Log the processed sample to the checkpoint file
    echo "$sample_name" >> "$qc_checkpoint_file"
    
done < "$SAMPLE_LIST"


