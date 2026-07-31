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

# --- ONLY SETTING ---
BASE_NAME="hgmm_12k" # "5k_hgmm_3p_nextgem"
TYPES=("graft" "host" "ambiguous" "neither")

# --- PROCESSING LOOP ---
for TYPE in "${TYPES[@]}"
do
    # Define directory based on the naming from previous subset/sort steps
    # Note: Ensure this matches the OUTPUT_DIR used in your 03_subset.sh
    DIR="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_classified_${TYPE}"
    
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

    # Determine Reference and Config Filename based on TYPE
#    if [ "$TYPE" == "graft" ]; then
#        REF="/lustre/home/juicer/ExtData/10x/refdata-gex-GRCh38-2024-A"
#    else
#        REF="/lustre/home/juicer/ExtData/10x/refdata-gex-GRCm39-2024-A"
#    fi
    case "$TYPE" in
        "graft")
            REF="/lustre/home/juicer/ExtData/10x/refdata-gex-GRCh38-2024-A"
            ;;
        "host")
            REF="/lustre/home/juicer/ExtData/10x/refdata-gex-GRCm39-2024-A"
            ;;
        *)
            # The "*" acts as a catch-all for "ambiguous", "neither", or anything else
            REF="/lustre/home/juicer/ExtData/10x/refdata-gex-GRCh38_and_GRCm39-2024-A"
            ;;
    esac

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
        mv "sorted_${BASE_NAME}_classified-${TYPE}.I2.fq.gz" "${SAMPLE_ID}_S1_L001_I2_001.fastq.gz"
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

echo "--------------------------------------------------------"
echo "All preparation steps complete for Graft and Host."
echo "--------------------------------------------------------"
