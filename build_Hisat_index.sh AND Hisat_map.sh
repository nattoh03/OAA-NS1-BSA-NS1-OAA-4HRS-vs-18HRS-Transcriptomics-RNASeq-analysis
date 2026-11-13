################################################################################################################################
Build the index
################################################################################################################################
#!/bin/bash
#SBATCH --job-name=hisat2_build
#SBATCH --output=logs/hisat2_build_%j.out
#SBATCH --error=logs/hisat2_build_%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=12
#SBATCH --mem=128G
#SBATCH --partition=day

# load the module
module load HISAT2/2.2.1-gompi-2024a

# Define working directory
BASE_DIR="$HOME/palmer_scratch/RNASeq"
REF_DIR="${BASE_DIR}/reference"

# download the reference files (.fna and .gft)
### https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/204/515/GCF_002204515.2_AaegL5.0/
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/204/515/GCF_002204515.2_AaegL5.0/GCF_002204515.2_AaegL5.0_genomic.fna.gz
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/204/515/GCF_002204515.2_AaegL5.0/GCF_002204515.2_AaegL5.0_genomic.gtf.gz

# Create reference directory and move files there to keep your root clean (optional, or keep them in place)
mkdir -p "${REF_DIR}"
# If you want to move them into reference/, uncomment the lines below:
# mv "${BASE_DIR}/GCF_002204515.2_AaegL5.0_genomic.fna" "${REF_DIR}/"
# mv "${BASE_DIR}/GCF_002204515.2_AaegL5.0_genomic.gtf" "${REF_DIR}/"

# Since they are currently in your main RNASeq directory, we can point directly to them:
GENOME_FASTA="${BASE_DIR}/GCF_002204515.2_AaegL5.0_genomic.fna"
ANNOTATION_GTF="${BASE_DIR}/GCF_002204515.2_AaegL5.0_genomic.gtf"

# Output index prefix path
INDEX_DIR="${BASE_DIR}/hisat2_index"
INDEX_PREFIX="${INDEX_DIR}/AaegL5_tran"

# Create output index directory
mkdir -p "${INDEX_DIR}"
mkdir -p "${BASE_DIR}/logs"

echo "Starting HISAT2 index build for Aedes aegypti at $(date)"
echo "--------------------------------------------------"

# Step 1: Extract splice sites and exons from the GTF annotation
echo "Extracting splice sites and exons..."
hisat2_extract_splice_sites.py "${ANNOTATION_GTF}" > "${INDEX_DIR}/splicesites.txt"
hisat2_extract_exons.py "${ANNOTATION_GTF}" > "${INDEX_DIR}/exons.txt"

# Step 2: Build the splice-aware HISAT2 index
echo "Building HISAT2 index..."
hisat2-build \
    -p 12 \
    --ss "${INDEX_DIR}/splicesites.txt" \
    --exon "${INDEX_DIR}/exons.txt" \
    "${GENOME_FASTA}" \
    "${INDEX_PREFIX}"

echo "--------------------------------------------------"
echo "HISAT2 index build completed successfully at $(date)"
echo "Index base path: ${INDEX_PREFIX}"



################################################################################################################################
RUN HISAT2 AS ARRAY, TO SPEED UP MAPPING
#################################################################################################################################
#!/bin/bash
#SBATCH --job-name=hisat2_array
#SBATCH --output=logs2Array_align/hisat2_array_%A_%a.out
#SBATCH --error=logs2Array_align/hisat2_array_%A_%a.err
#SBATCH --time=30:00:00
#SBATCH --cpus-per-task=12
#SBATCH --mem=128G
#SBATCH --partition=week
#SBATCH --array=1-32

# Load required modules
module load HISAT2/2.2.1-gompi-2024a
module load SAMtools/1.21-GCC-13.3.0

# Define directories
BASE_DIR="/home/gi64/palmer_scratch/RNASeq"
TRIM_DIR="${BASE_DIR}/trimmed_data2"
ALIGN_DIR="${BASE_DIR}/aligned_data"
REPORT_DIR="${BASE_DIR}/alignment_reports"
GENOME_INDEX="${BASE_DIR}/hisat2_index/AaegL5_tran"

# Create output directories
mkdir -p "${ALIGN_DIR}" "${REPORT_DIR}" "${BASE_DIR}/logs2Array_align"

# Map the SLURM array task ID (1 to 32) to the corresponding sample number
sample_num=${SLURM_ARRAY_TASK_ID}
sample_name="Sample_${sample_num}_S${sample_num}_L004"

# Define fastq paths for this specific sample
r1_file="${TRIM_DIR}/${sample_name}_R1_val_1.fastq.gz"
r2_file="${TRIM_DIR}/${sample_name}_R2_val_2.fastq.gz"

echo "--------------------------------------------------"
echo "Task ID: ${SLURM_ARRAY_TASK_ID} | Processing sample: ${sample_name} at $(date)"

# Check if input files exist before running
if [ -f "$r1_file" ] && [ -f "$r2_file" ]; then
    # Run HISAT2 and pipe directly to samtools sort
    hisat2 -p 12 -x "${GENOME_INDEX}" \
           -1 "$r1_file" \
           -2 "$r2_file" \
           --summary-file "${REPORT_DIR}/${sample_name}_hisat2_summary.txt" | \
    samtools view -bS - | \
    samtools sort -@ 4 -o "${ALIGN_DIR}/${sample_name}_sorted.bam"
    
    # Index the sorted BAM file
    samtools index "${ALIGN_DIR}/${sample_name}_sorted.bam"
    
    echo "Successfully finished: ${sample_name} at $(date)"
else
    echo "[!] Error: FASTQ files for ${sample_name} not found in ${TRIM_DIR}!" >&2
    exit 1
fi
################################################################################################################################


