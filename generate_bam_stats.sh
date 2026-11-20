## create script to obtain stats from filtered reads use nano generate_bam_stats.sh
#!/bin/bash
#SBATCH --job-name=bam_stats
#SBATCH --output=logs2_align/bam_stats_%j.out
#SBATCH --error=logs2_align/bam_stats_%j.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=day

# Load required modules (this versions are labelled D on Yale clustere i.e default)
module load SAMtools/1.21-GCC-13.3.0
module load MultiQC/1.10.1-foss-2020b-Python-3.8.6

# Define directories
BASE_DIR="/home/gi64/palmer_scratch/RNASeq"
FILTER_DIR="${BASE_DIR}/filtered_mapped_data"
STATS_DIR="${BASE_DIR}/bam_stats_filtered"

# Create output directories
mkdir -p "${STATS_DIR}"
mkdir -p "${BASE_DIR}/logs2_align"

echo "Starting BAM statistics generation at $(date)"
echo "--------------------------------------------------"

# Loop through filtered BAM files
for bam_file in "${FILTER_DIR}"/*_mq10.bam; do
    if [ -f "$bam_file" ]; then
        filename=$(basename "$bam_file")
        prefix="${filename%_mq10.bam}"
        
        echo "Generating stats for: $prefix"
        
        # 1. Flagstat: Overall QC metrics (reads mapped, properly paired, duplicates, etc.)
        samtools flagstat -@ 8 "$bam_file" > "${STATS_DIR}/${prefix}_mq10_flagstat.txt"
        
        # 2. Idxstats: Chromosome-level read distribution counts
        samtools idxstats "$bam_file" > "${STATS_DIR}/${prefix}_mq10_idxstats.txt"
        
        echo "Finished stats for: $prefix"
        echo "--------------------------------------------------"
    fi
done

echo "All flagstat and idxstats reports generated. Running MultiQC..."

# Run MultiQC to aggregate all text reports into a single visual HTML dashboard
multiqc "${STATS_DIR}" -o "${STATS_DIR}"

echo "--------------------------------------------------"
echo "Summary statistics pipeline completed successfully at $(date)"
