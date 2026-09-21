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

# --- SETTINGS ---
BASE_NAME="hgmm_12k" #  "5k_hgmm_3p_nextgem"
TYPES=( "graft" "host" "ambiguous" "neither" )

# Derived Paths
MERGED_DIR="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_merged"
CLASS_DIR="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_classified"
SEQKIT=~/.local/bin/seqkit

# --- PROCESSING LOOP ---
for TYPE in "${TYPES[@]}"
do
    OUTPUT_DIR="${CLASS_DIR}_${TYPE}"
    echo "-------------------------------------------------------"
    echo "Starting synchronization for TYPE: ${TYPE}"
    echo "Output Directory: ${OUTPUT_DIR}"
    echo "-------------------------------------------------------"

    # 0. Create type-specific output directory
    mkdir -p "${OUTPUT_DIR}"

    # 1. Generate a clean list of read IDs from the classified R1 file
    echo "[1/3] Extracting ${TYPE} read IDs..."
    zcat "${CLASS_DIR}/${BASE_NAME}_classified-${TYPE}.1.fq.gz" | \
        awk 'NR%4==1 {print $1}' | \
        sed 's/^@//' > "${OUTPUT_DIR}/${TYPE}_ids.txt"

    # 2. Use seqkit grep to filter the merged Index files
    # -j matches the --cpus-per-task for optimal performance
    echo "[2/3] Filtering I1 and I2 Index files..."
    ${SEQKIT} grep -j $SLURM_CPUS_PER_TASK -f "${OUTPUT_DIR}/${TYPE}_ids.txt" \
        "${MERGED_DIR}/merged_I1.fastq.gz" \
        -o "${OUTPUT_DIR}/${BASE_NAME}_classified-${TYPE}.I1.fq.gz"

    ${SEQKIT} grep -j $SLURM_CPUS_PER_TASK -f "${OUTPUT_DIR}/${TYPE}_ids.txt" \
        "${MERGED_DIR}/merged_I2.fastq.gz" \
        -o "${OUTPUT_DIR}/${BASE_NAME}_classified-${TYPE}.I2.fq.gz"

    # 3. Copy the classified R1 and R2 into the same folder
    echo "[3/3] Moving R1 and R2 into the specific folder..."
    cp "${CLASS_DIR}/${BASE_NAME}_classified-${TYPE}.1.fq.gz" "${OUTPUT_DIR}/"
    cp "${CLASS_DIR}/${BASE_NAME}_classified-${TYPE}.2.fq.gz" "${OUTPUT_DIR}/"

    echo "DONE: Synchronization complete for ${TYPE}."
    echo ""
done

echo "All types processed successfully."
