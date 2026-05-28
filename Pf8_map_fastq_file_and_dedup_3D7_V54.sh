#!/bin/bash

: '
This script performs mapping, conversion of SAM to BAM, fixing mate information, sorting BAM files, adding read groups, removing duplicates with Picard, and indexing.
'

## Ensure necessary environment variables are set
if [ -z "$TRIMDIR" ] || [ -z "$MAPDIR" ] || [ -z "$REFGENOME" ] || [ -z "$SAMPLE_LIST" ] || [ -z "$map_checkpoint_file" ] || [ -z "$BWA" ] || [ -z "$SAMTOOLS" ] || [ -z "$GATK" ] || [ -z "$threads" ]; then
    echo "One or more required environment variables are not set. Please check and set the following variables: TRIMDIR, MAPDIR, REFGENOME, SAMPLE_LIST, map_checkpoint_file, BWA, SAMTOOLS, GATK, threads."
    exit 1
fi

## Check if tools and reference genome exist
if [ ! -f "$REFGENOME" ]; then
    echo "Reference genome file not found: $REFGENOME"
    exit 1
fi
if ! command -v "$BWA" &> /dev/null; then
    echo "BWA not found: $BWA"
    exit 1
fi
if ! command -v "$SAMTOOLS" &> /dev/null; then
    echo "Samtools not found: $SAMTOOLS"
    exit 1
fi
if ! command -v "$GATK" &> /dev/null; then
    echo "GATK not found: $GATK"
    exit 1
fi


############# Process each sample from SAMPLE_LIST: mapping on 3D7 #############################################
while IFS= read -r sample; do

    # Remove any trailing carriage return characters
    sample=$(echo "$sample" | tr -d '\r')

    sample_name=$(basename "$sample")
    trimmed_r1="${TRIMDIR}/${sample_name}_1_trimmed.fastq.gz"
    trimmed_r2="${TRIMDIR}/${sample_name}_2_trimmed.fastq.gz"
    sorted_bam_file="${MAPDIR}/${sample_name}_sorted.bam"
    rg_bam_file="${MAPDIR}/${sample_name}_sorted_with_rg.bam"
    dedup_bam_file="${MAPDIR}/${sample_name}_sorted_dedup.bam"
    picard_markdup_log="${MAPDIR}/${sample_name}_markdup.log"
    picard_addrg_log="${MAPDIR}/${sample_name}_addrg.log"
    dedup_metrics_file="${MAPDIR}/${sample_name}_dedup_metrics.txt"

    # Check if the sample has already been processed
    if grep -q "^${sample_name}$" "$map_checkpoint_file"; then
        echo "Sample $sample_name already processed for mapping. Skipping..."
        continue
    fi

    # Step 4–7: Mapping + SAM to BAM + Fixmate + Sorting (collapsed)
    if [ ! -f "$sorted_bam_file" ]; then
        echo "Mapping, converting, fixing mates, and sorting for $sample_name..."
        
        # First create a sorted BAM without MD tags
        temp_sorted="${MAPDIR}/${sample_name}.temp.sorted.bam"
        
        $BWA mem -K 100000000 -t "$threads" "$REFGENOME" -M "$trimmed_r1" "$trimmed_r2" | \
            $SAMTOOLS view -bS -@ "$threads" - | \
            $SAMTOOLS fixmate -m -@ "$threads" - - | \
            $SAMTOOLS sort -@ "$threads" -l 0 -o "$temp_sorted" - || {
                echo "Initial mapping pipeline failed for $sample_name"
                exit 1
            }
        
        # Then add MD tags
        echo "Calculating MD tags for $sample_name..."
        $SAMTOOLS calmd -@ "$threads" -b "$temp_sorted" "$REFGENOME" > "$sorted_bam_file" || {
            echo "samtools calmd failed for $sample_name"
            exit 1
        }
        
        # Clean up temp file
        rm -f "$temp_sorted"
        
        # Index the sorted BAM
        echo "Indexing BAM file for $sample_name..."
        $SAMTOOLS index -@ "$threads" "$sorted_bam_file" || {
            echo "Indexing failed for $sample_name"
            exit 1
        }
        
        echo "Completed mapping and indexing for $sample_name"
    else
        echo "Mapping and preprocessing already done for $sample_name. Skipping..."
    fi    

    # Step 8: Adding read groups with GATK
    if [ ! -f "$rg_bam_file" ]; then
        echo "Adding read groups for $sample_name..."
        $GATK AddOrReplaceReadGroups \
            --INPUT "$sorted_bam_file" \
            --OUTPUT "$rg_bam_file" \
            --RGID "group1" \
            --RGLB "lib1" \
            --RGPL "ILLUMINA" \
            --RGPU "unit1" \
            --RGSM "$sample_name" \
            > "$picard_addrg_log" 2>&1 || {
                echo "AddOrReplaceReadGroups failed for $sample_name"
                exit 1
            }
        rm "$sorted_bam_file"
    else
        echo "Read groups already added for $sample_name. Skipping..."
    fi

    # Step 9: Removing duplicates with GATK
    if [ ! -f "$dedup_bam_file" ]; then
        echo "Marking duplicates for $sample_name..."

        mkdir -p tmp_${sample_name}

        $GATK MarkDuplicates \
            --INPUT "$rg_bam_file" \
            --OUTPUT "$dedup_bam_file" \
            --ASSUME_SORT_ORDER coordinate \
            --METRICS_FILE "$dedup_metrics_file" \
            --VALIDATION_STRINGENCY SILENT \
            --TMP_DIR tmp_${sample_name} \
            --CREATE_INDEX true \
            > "$picard_markdup_log" 2>&1 || {
                echo "MarkDuplicates failed for $sample_name"
                exit 1
            }
        # Rename index file from .bai to .bam.bai
        if [ -f "${dedup_bam_file%.bam}.bai" ]; then
            mv "${dedup_bam_file%.bam}.bai" "${dedup_bam_file}.bai"
        fi

        rm "$rg_bam_file"
        rm -rf tmp_${sample_name}
        
    else
        echo "Duplicate marking already done for $sample_name. Skipping..."
    fi
    # Step 10: Indexing final deduplicated BAM
    if [ ! -f "${dedup_bam_file}.bai" ]; then
        echo "Indexing BAM for $sample_name..."
        $SAMTOOLS index -@ $threads "$dedup_bam_file" || {
            echo "Indexing failed for $sample_name"
            exit 1
        }
    else
        echo "Indexing already done for $sample_name. Skipping..."
    fi

    echo "Completed processing for $sample_name."

    # Log the processed sample to the checkpoint file
    echo "$sample_name" >> "$map_checkpoint_file"
    
done < "$SAMPLE_LIST"

echo "All samples processed."
