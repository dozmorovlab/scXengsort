#!/bin/bash
#SBATCH --job-name=xengsort_05_prepare
#SBATCH --output=xengsort_05_prepare.%j.out
#SBATCH --error=xengsort_05_prepare.%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
# SBATCH --mem=10G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=xengsort_config.sh
source "${SCRIPT_DIR}/xengsort_config.sh"

# --- PROCESSING LOOP ---
for TYPE in "${CLASSIFICATION_TYPES[@]}"
do
    # Define directory based on the naming from previous subset/sort steps
    # Note: Ensure this matches the OUTPUT_DIR used in your 03_subset.sh
    DIR="$(classified_type_dir "$TYPE")"

    # Sample ID used inside Cell Ranger
    SAMPLE_ID="${BASE_NAME}_${TYPE}"

    echo "--------------------------------------------------------"
    echo "Finalizing ${TYPE} files in: $DIR"
    echo "--------------------------------------------------------"

    # Check if directory exists
    if [ ! -d "$DIR" ]; then
        echo "[ERROR] Directory $DIR does not exist. Skipping $TYPE."
        continue
    fi

    REF="$(cellranger_reference_for_type "$TYPE")"

    # Unified config naming
    CONFIG_NAME="${BASE_NAME}_multi_config_${TYPE}.csv"

    cd "$DIR"

    # 1. Rename files to Cell Ranger compatible format
    # Using the standard: [SampleName]_S1_L001_[Read]_001.fastq.gz
    echo "Renaming sorted files for ${TYPE}..."

    # Check for file existence before moving to avoid errors
    if [ -f "sorted_${BASE_NAME}_classified-${TYPE}.1.fq.gz" ]; then
        mv "sorted_${BASE_NAME}_classified-${TYPE}.1.fq.gz"  "${SAMPLE_ID}_S1_L001_R1_001.fastq.gz"
        mv "sorted_${BASE_NAME}_classified-${TYPE}.2.fq.gz"  "${SAMPLE_ID}_S1_L001_R2_001.fastq.gz"
        mv "sorted_${BASE_NAME}_classified-${TYPE}.I1.fq.gz" "${SAMPLE_ID}_S1_L001_I1_001.fastq.gz"
        if [ -f "sorted_${BASE_NAME}_classified-${TYPE}.I2.fq.gz" ]; then
            mv "sorted_${BASE_NAME}_classified-${TYPE}.I2.fq.gz" "${SAMPLE_ID}_S1_L001_I2_001.fastq.gz"
        else
            echo "[INFO] No sorted I2 FASTQ found; preparing single-index data."
        fi
        echo "Check: Filenames updated to Cell Ranger format."
    else
        echo "[WARNING] Sorted files not found in $DIR. They may have already been renamed."
    fi

    # 2. Generate the Cell Ranger multi config file
    echo "Generating ${CONFIG_NAME}..."

    cat <<EOF > "${CONFIG_NAME}"
[gene-expression]
reference,${REF}
create-bam,false

[libraries]
fastq_id,fastqs,lanes,feature_types
${SAMPLE_ID},${DIR},1,Gene Expression
EOF

    echo "DONE: Config file created at ${DIR}/${CONFIG_NAME}"
done

# Check file integrity
find . -type f -name "${BASE_NAME}_*_S1_L001_R[12]_001.fastq.gz" -print0 | while IFS= read -r -d '' file; do
  if ! gzip -t "$file"; then
    echo "Integrity check failed: $file"
  fi
done


echo "--------------------------------------------------------"
echo "All preparation steps complete for Graft and Host."
echo "--------------------------------------------------------"
