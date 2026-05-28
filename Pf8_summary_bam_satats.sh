#!/bin/bash

# Define directories
MAPDIR="/media/student/Seagate_Bas/CRYPTOTYPE_Project/sWGA_Cryptotype/Pf8_MalariaGen/Batch_script_Pf8/mapped_reads"
BAM_STATS="${MAPDIR}/samtools_files"

mkdir -p "$BAM_STATS"

mapping_stats_file="${BAM_STATS}/summary_bamstats.txt"
genome_size=23334207

# Write header
echo -e "SampleID\tTotal_reads\tPaired_reads\tProperly_paired\tDuplicated_reads\t%Mapped_reads\t%Properly_paired\t%Unmapped_reads\t%Genome_Coverage_>1X\t%Genome_Coverage_>3X\t%Genome_Coverage_>5X\t%Callable\t%MapQ0_reads" > "$mapping_stats_file"

for bam_file in "$MAPDIR"/*_sorted_dedup_bqsr.bam; do
    [ ! -f "$bam_file" ] && continue
    
    sample_id=$(basename "$bam_file" | sed 's/_sorted_dedup_bqsr.bam//')
    echo "Processing $sample_id..."
    
    # Get flagstat stats
    map_stats=$(samtools flagstat "$bam_file")
    total_reads=$(echo "$map_stats" | awk 'NR==1 {print $1}')
    paired_reads=$(echo "$map_stats" | awk 'NR==9 {print $1}')
    properly_paired=$(echo "$map_stats" | awk 'NR==12 {print $1}')
    duplicated_reads=$(echo "$map_stats" | awk 'NR==5 {print $1}')
    mapped_reads=$(echo "$map_stats" | awk 'NR==7 {print $1}')
    unmapped_reads=$((total_reads - mapped_reads))
    
    # Calculate percentages
    mapped_percentage=$(awk "BEGIN {printf \"%.2f\", ($mapped_reads/$total_reads)*100}")
    properly_paired_percentage=$(awk "BEGIN {printf \"%.2f\", ($properly_paired/$paired_reads)*100}")
    unmapped_percentage=$(awk "BEGIN {printf \"%.2f\", ($unmapped_reads/$total_reads)*100}")
    
    # Get percentage of reads with mapping quality 0
    # Count reads with MAPQ=0 from the BAM file
    mapq0_reads=$(samtools view -c -q 0 "$bam_file" 2>/dev/null)
    mapq0_percentage=$(awk "BEGIN {printf \"%.2f\", ($mapq0_reads/$mapped_reads)*100}")
    
    # Compute genome coverage statistics
    coverage=$(samtools depth -a -Q 0 "$bam_file" 2>/dev/null | awk -v gs="$genome_size" '
        {
            if ($3 > 1) cov1++
            if ($3 > 3) cov3++
            if ($3 > 5) cov5++
            
            if ($3 >= 5) {
                mapq0_pct = ($4 / $3) * 100
                if (mapq0_pct < 10) callable++
            }
        }
        END {
            if (gs > 0) {
                printf "%.2f\t%.2f\t%.2f\t%.2f", 
                    (cov1/gs)*100, 
                    (cov3/gs)*100, 
                    (cov5/gs)*100, 
                    (callable/gs)*100
            } else {
                printf "NA\tNA\tNA\tNA"
            }
        }'
    )
    
    echo -e "${sample_id}\t${total_reads}\t${paired_reads}\t${properly_paired}\t${duplicated_reads}\t${mapped_percentage}\t${properly_paired_percentage}\t${unmapped_percentage}\t${coverage}\t${mapq0_percentage}" >> "$mapping_stats_file"
    
done

echo "Analysis complete! Results: $mapping_stats_file"
