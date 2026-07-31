#!/bin/bash
#SBATCH --job-name=xengsort_00_cellranger_full_data
#SBATCH --output=xengsort_00_cellranger_full_%j.out
#SBATCH --error=xengsort_00_cellranger_full_%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
#SBATCH --mem=140G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24

# --- CONFIGURATION ---
BASE_NAME="hgmm_12k" #  "5k_hgmm_3p_nextgem"
PROJECT_ROOT="/lustre/home/juicer/MultipletR.dev"
CELLRANGER_BIN="${PROJECT_ROOT}/cellranger-10.0.0/bin/cellranger"

# Paths
FASTQ_DIR="${PROJECT_ROOT}/${BASE_NAME}_fastqs"
CONFIG_FILE="${PROJECT_ROOT}/${BASE_NAME}_full_multi_config.csv"
OUTPUT_ID="${BASE_NAME}_multi"

# Reference (Mixed Barnyard)
REF="/lustre/home/juicer/ExtData/10x/refdata-gex-GRCh38_and_GRCm39-2024-A"

cd $PROJECT_ROOT

echo "--------------------------------------------------------"
echo "Aggregating all lanes and libraries for: $BASE_NAME"
echo "--------------------------------------------------------"

# 1. Generate the multi config file
echo "[1/2] Generating configuration file..."

cat <<EOF > "$CONFIG_FILE"
[gene-expression]
reference,${REF}
create-bam,false

[libraries]
fastq_id,fastqs,lanes,feature_types
EOF

# Detect unique prefixes (e.g., handles both 'gex1' and 'gex2')
# This extracts the part of the filename before the '_S[N]_L00[N]' part
SAMPLE_IDS=$(ls ${FASTQ_DIR}/*.fastq.gz | xargs -n 1 basename | sed 's/_S[0-9].*//' | sort -u)

for ID in $SAMPLE_IDS; do
    echo "Adding $ID to unified sample pool..."
    # 'any' tells Cell Ranger to find all lanes (L001, L002, L003, L004) for this ID
    echo "${ID},${FASTQ_DIR},any,Gene Expression" >> "$CONFIG_FILE"
done

# 2. Run Cell Ranger Multi
echo "[2/2] Launching Cell Ranger Multi..."

# Clean up existing run folder if necessary
if [ -d "$OUTPUT_ID" ]; then
    echo "Removing existing output folder $OUTPUT_ID"
    rm -rf "$OUTPUT_ID"
fi

$CELLRANGER_BIN multi --id="$OUTPUT_ID" \
                      --csv="$CONFIG_FILE" \
                      --localcores=$SLURM_CPUS_PER_TASK \
                      --localmem=$((SLURM_MEM_PER_NODE / 1024))




echo "--------------------------------------------------------"
echo "Moving configuration file $(basename "${CONFIG_FILE}") to ${OUTPUT_ID}"
echo "--------------------------------------------------------"

# Using quotes to handle spaces and the -v flag to confirm the move in logs
mv "${CONFIG_FILE}" "${OUTPUT_ID}/"

echo "--------------------------------------------------------"
echo "Unified Full Data Analysis Complete."
echo "--------------------------------------------------------"
