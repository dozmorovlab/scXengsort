#!/bin/bash
#SBATCH --job-name=xengsort_04_sort
#SBATCH --output=xengsort_04_sort.%j.out
#SBATCH --error=xengsort_04_sort.%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
#SBATCH --mem=120G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=xengsort_config.sh
source "${SCRIPT_DIR}/xengsort_config.sh"

# --- PROCESSING LOOP ---
for TYPE in "${CLASSIFICATION_TYPES[@]}"
do
    # Re-evaluate paths for each type
    DIR="$(classified_type_dir "$TYPE")"
    TMP_DIR="${DIR}/sort_tmp"
    ID_FILE="${DIR}/${TYPE}_ids.txt"

    echo "--------------------------------------------------------"
    echo "Starting Sort & Verify for: $TYPE"
    echo "Target Directory: $DIR"
    echo "--------------------------------------------------------"

    if [ ! -d "$DIR" ]; then
        echo "[ERROR] Directory $DIR does not exist. Skipping $TYPE."
        continue
    fi

    mkdir -p "$TMP_DIR"
    cd "$DIR"

    # Define required read and I1 files based on the classification naming convention.
    FILES=(
        "${BASE_NAME}_classified-${TYPE}.1.fq.gz"
        "${BASE_NAME}_classified-${TYPE}.2.fq.gz"
        "${BASE_NAME}_classified-${TYPE}.I1.fq.gz"
    )
    I2_FILE="${BASE_NAME}_classified-${TYPE}.I2.fq.gz"
    if [ -f "$I2_FILE" ]; then
        FILES+=("$I2_FILE")
    else
        echo "[INFO] No I2 FASTQ found; sorting single-index data."
    fi

    # 1. Count IDs in the reference list
    if [ -f "$ID_FILE" ]; then
        REF_COUNT=$(wc -l < "$ID_FILE")
        echo "[CHECK] Reference IDs in ${TYPE}_ids.txt: $REF_COUNT"
    else
        echo "[WARNING] ID file $ID_FILE not found. Verification will be incomplete."
        REF_COUNT=0
    fi

    # 2. Process each file
    for gz_file in "${FILES[@]}"; do
        if [ ! -f "$gz_file" ]; then
            echo "[ERROR] File not found: $gz_file"
            continue
        fi

        echo "Processing $gz_file..."

        # FASTQ Linearization and Sorting
        # -k1,1: Sort by ID
        # -S 60G: Buffer size (matches 80G requested, leaving overhead)
        zcat "$gz_file" | \
        paste - - - - | \
        sort -k1,1 -T "$TMP_DIR" --parallel=$SLURM_CPUS_PER_TASK -S 120G | \
        tr '\t' '\n' | \
        gzip > "sorted_$gz_file"

        # 3. Counting and Verification
        SORTED_COUNT=$(zcat "sorted_$gz_file" | awk 'NR%4==1' | wc -l)

        echo "   -> Result: sorted_$gz_file"
        echo "   -> Read Count: $SORTED_COUNT"

        if [ "$REF_COUNT" -gt 0 ]; then
            if [ "$SORTED_COUNT" -eq "$REF_COUNT" ]; then
                echo "   [OK] Count matches reference ID list."
            else
                echo "   [WARNING] COUNT MISMATCH!"
                echo "   Expected: $REF_COUNT | Found: $SORTED_COUNT"
            fi
        fi
    done

    # Cleanup temp files for this type before moving to the next
    rm -rf "$TMP_DIR"
    echo "Processing Complete for $TYPE"
    echo "--------------------------------------------------------"
done

echo "Global Sort & Verify Job Finished."
