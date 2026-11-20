### create nano filterAlignedReads.sh
#!/bin/bash
#SBATCH --job-name=samtools_filter
#SBATCH --output=logs2_align/filter_%j.out
#SBATCH --error=logs2_align/filter_%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=day

# Load required modules
module load SAMtools/1.21-GCC-13.3.0

# Define directories
BASE_DIR="/home/gi64/palmer_scratch/RNASeq"
ALIGN_DIR="${BASE_DIR}/aligned_data"
FILTER_DIR="${BASE_DIR}/filtered_mapped_data"

# Create output directory for filtered bams
mkdir -p "${FILTER_DIR}"

echo "Starting BAM filtering at $(date)"
echo "--------------------------------------------------"

# Loop through all sorted BAM files
for bam_file in "${ALIGN_DIR}"/*_sorted.bam; do
    if [ -f "$bam_file" ]; then
        # Extract file name and sample prefix
        filename=$(basename "$bam_file")
        prefix="${filename%_sorted.bam}"
        
        output_bam="${FILTER_DIR}/${prefix}_mq10.bam"
        
        echo "Filtering sample: $prefix"
        
        # Run samtools view to filter MAPQ >= 10 (-q 10) and drop unmapped (-F 4)
        samtools view \
            -b \
            -q 10 \
            -F 4 \
            -@ 8 \
            "$bam_file" \
            -o "$output_bam"
        
        # Index the newly filtered BAM file
        samtools index -@ 8 "$output_bam"
        
        echo "Completed sample: $prefix"
        echo "--------------------------------------------------"
    fi
done

echo "All BAM files filtered and indexed successfully at $(date)"
