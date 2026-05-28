#!/bin/bash
: '
This script performs the statistics on the recalibrated bam files.
'

############ Process each sample from SAMPLE_LIST #############################################
for BAM_FILE in "$MAPDIR"/*_sorted_dedup_bqsr.bam; do
    
    # Skip if no files match the pattern
    [ -e "$BAM_FILE" ] || continue
    
    # Extract sample name from the full path
    sample_name=$(basename "$BAM_FILE" _sorted_dedup_bqsr.bam)
    
    # Define output file path
    bam_stats="${BAM_STATS}/${sample_name}_bamstats.txt"
    
    echo "Processing $sample_name..."

    # Check if input BAM exists
    if [ ! -f "$BAM_FILE" ]; then
        echo "ERROR: BAM file not found for $sample_name: $BAM_FILE"
        exit 1
    fi

    # ===== STEP 1: samtools stats =====
    if [ ! -f "$bam_stats" ]; then
        echo "Running samtools stats for $sample_name..."
        
        samtools stats "$BAM_FILE" -@ "$threads" > "$bam_stats" || {
            echo "ERROR: samtools stats failed for $sample_name"
            exit 1
        }
        
        echo "samtools stats completed for $sample_name"
    else
        echo "samtools stats already exists for $sample_name. Skipping..."
    fi
done 

echo "All samples statistics completed successfully!"
