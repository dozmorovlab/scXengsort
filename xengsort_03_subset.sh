#!/bin/bash
#SBATCH --job-name=xengsort_03_subset
#SBATCH --output=xengsort_03_subset.%j.out
#SBATCH --error=xengsort_03_subset.%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
#SBATCH --mem=100G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32  # Increased to match seqkit threads for speed

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=xengsort_config.sh
source "${SCRIPT_DIR}/xengsort_config.sh"

if ! command -v "$SEQKIT_BIN" > /dev/null 2>&1; then
    echo "[ERROR] seqkit executable not found: $SEQKIT_BIN" >&2
    exit 1
fi

# --- PROCESSING LOOP ---
for TYPE in "${CLASSIFICATION_TYPES[@]}"
do
    OUTPUT_DIR="$(classified_type_dir "$TYPE")"
    echo "-------------------------------------------------------"
    echo "Starting synchronization for TYPE: ${TYPE}"
    echo "Output Directory: ${OUTPUT_DIR}"
    echo "-------------------------------------------------------"

    # 0. Create type-specific output directory
    mkdir -p "${OUTPUT_DIR}"

    # 1. Generate a clean list of read IDs from the classified R1 file
    echo "[1/3] Extracting ${TYPE} read IDs..."
    zcat "${CLASSIFIED_DIR}/${BASE_NAME}_classified-${TYPE}.1.fq.gz" | \
        awk 'NR%4==1 {print $1}' | \
        sed 's/^@//' > "${OUTPUT_DIR}/${TYPE}_ids.txt"

    # 2. Use seqkit grep to filter the merged Index files
    # -j matches the --cpus-per-task for optimal performance
    echo "[2/3] Filtering I1 index files..."
    "$SEQKIT_BIN" grep -j "$SLURM_CPUS_PER_TASK" -f "${OUTPUT_DIR}/${TYPE}_ids.txt" \
        "${MERGED_DIR}/merged_I1.fastq.gz" \
        -o "${OUTPUT_DIR}/${BASE_NAME}_classified-${TYPE}.I1.fq.gz"

    if [ -f "${MERGED_DIR}/merged_I2.fastq.gz" ]; then
        echo "Filtering I2 index files..."
        "$SEQKIT_BIN" grep -j "$SLURM_CPUS_PER_TASK" -f "${OUTPUT_DIR}/${TYPE}_ids.txt" \
            "${MERGED_DIR}/merged_I2.fastq.gz" \
            -o "${OUTPUT_DIR}/${BASE_NAME}_classified-${TYPE}.I2.fq.gz"
    else
        echo "No merged I2 FASTQ found; skipping I2 subsetting."
    fi

    # 3. Link the classified R1 and R2 into the type-specific folder.
    echo "[3/3] Linking R1 and R2 into the specific folder..."
    ln -sfn "${CLASSIFIED_DIR}/${BASE_NAME}_classified-${TYPE}.1.fq.gz" \
        "${OUTPUT_DIR}/${BASE_NAME}_classified-${TYPE}.1.fq.gz"
    ln -sfn "${CLASSIFIED_DIR}/${BASE_NAME}_classified-${TYPE}.2.fq.gz" \
        "${OUTPUT_DIR}/${BASE_NAME}_classified-${TYPE}.2.fq.gz"

    echo "DONE: Synchronization complete for ${TYPE}."
    echo ""
done

echo "All types processed successfully."
