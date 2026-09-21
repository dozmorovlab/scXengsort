#!/bin/bash
#SBATCH --job-name=xengsort_06_cellranger
#SBATCH --output=xengsort_06_cellranger.%j.out
#SBATCH --error=xengsort_06_cellranger.%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
#SBATCH --mem=140G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24

# --- ONLY SETTING ---
BASE_NAME="hgmm_12k" # "5k_hgmm_3p_nextgem"
# Run one type at a time (loop still works with a scalar); switch to the full
# array ("graft" "host" "ambiguous" "neither") to process all four in one job.
TYPES="ambiguous"

# --- GLOBAL PATHS ---
PROJECT_ROOT="/lustre/home/juicer/MultipletR.dev"
CELLRANGER_BIN="${PROJECT_ROOT}/cellranger-10.0.0/bin/cellranger"

# Navigate to project root so the output folders are created there
cd $PROJECT_ROOT

# --- PROCESSING LOOP ---
for TYPE in "${TYPES[@]}"
do
    # 1. Define dynamic paths (matching your 05_prepare.sh output)
    DATA_DIR="${PROJECT_ROOT}/${BASE_NAME}_classified_${TYPE}"
    CONFIG_FILE="${DATA_DIR}/${BASE_NAME}_multi_config_${TYPE}.csv"
    OUTPUT_NAME="${BASE_NAME}_${TYPE}_multi"

    echo "--------------------------------------------------------"
    echo "Starting Cell Ranger Multi for: $TYPE"
    echo "Config: $CONFIG_FILE"
    echo "Output ID: $OUTPUT_NAME"
    echo "--------------------------------------------------------"

    # 2. Verify config exists before starting this iteration
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "[ERROR] Configuration file not found at $CONFIG_FILE. Skipping $TYPE."
        continue
    fi

    # 3. Check if output directory already exists to prevent Cell Ranger failure
    if [ -d "$PROJECT_ROOT/$OUTPUT_NAME" ]; then
        echo "[WARNING] Output directory $OUTPUT_NAME already exists. Cell Ranger will fail."
        echo "If you want to re-run, delete or move the existing folder first."
        continue
    fi

    # 4. Run Cell Ranger Multi
    # --localmem is converted from MB (SLURM default) to GB
    $CELLRANGER_BIN multi --id=$OUTPUT_NAME \
                          --csv=$CONFIG_FILE \
                          --localcores=$SLURM_CPUS_PER_TASK \
                          --localmem=$((SLURM_MEM_PER_NODE / 1024))

    echo "--------------------------------------------------------"
    echo "Cell Ranger completion for $TYPE"
    echo "--------------------------------------------------------"
done

echo "Global Cell Ranger submission job finished."
