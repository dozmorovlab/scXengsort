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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=xengsort_config.sh
source "${SCRIPT_DIR}/xengsort_config.sh"

cd "$PROJECT_ROOT"

echo "--------------------------------------------------------"
echo "Aggregating all lanes and libraries for: $BASE_NAME"
echo "--------------------------------------------------------"

# 1. Generate the multi config file
echo "[1/2] Generating configuration file..."

cat <<EOF > "$FULL_MULTI_CONFIG"
[gene-expression]
reference,${MIXED_REFERENCE}
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
    echo "${ID},${FASTQ_DIR},any,Gene Expression" >> "$FULL_MULTI_CONFIG"
done

# 2. Run Cell Ranger Multi
echo "[2/2] Launching Cell Ranger Multi..."

# Clean up existing run folder if necessary
if [ -d "$FULL_MULTI_OUTPUT" ]; then
    echo "Removing existing output folder $FULL_MULTI_OUTPUT"
    rm -rf "$FULL_MULTI_OUTPUT"
fi

"$CELLRANGER_BIN" multi --id="$FULL_MULTI_OUTPUT" \
                      --csv="$FULL_MULTI_CONFIG" \
                      --localcores=$SLURM_CPUS_PER_TASK \
                      --localmem=$((SLURM_MEM_PER_NODE / 1024))




echo "--------------------------------------------------------"
echo "Moving configuration file $(basename "${FULL_MULTI_CONFIG}") to ${FULL_MULTI_OUTPUT}"
echo "--------------------------------------------------------"

# Using quotes to handle spaces and the -v flag to confirm the move in logs
mv "${FULL_MULTI_CONFIG}" "${FULL_MULTI_OUTPUT}/"

echo "--------------------------------------------------------"
echo "Unified Full Data Analysis Complete."
echo "--------------------------------------------------------"
