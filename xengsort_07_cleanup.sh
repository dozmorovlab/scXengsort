#!/bin/bash

# --- CONFIGURATION ---
BASE_NAME="hgmm_12k" # "5k_hgmm_3p_nextgem"
PROJECT_ROOT="/lustre/home/juicer/MultipletR.dev"
DELETE_ALL=false
TYPES=( "graft" "host" "ambiguous" "neither" )

cd $PROJECT_ROOT

# Function for interactive confirmation
confirm_and_run() {
    local folder=$1
    local message=$2
    local cmd=$3

    if [ ! -d "$folder" ]; then
        echo "Skipping: $folder (not found)"
        return
    fi

    if [ "$DELETE_ALL" = true ]; then
        eval "$cmd"
    else
        read -p "Delete $folder ($message)? [y/n/a]: " choice
        case "$choice" in
            a|A ) DELETE_ALL=true; eval "$cmd" ;;
            y|Y ) eval "$cmd" ;;
            * ) echo "Skipping $folder..." ;;
        esac
    fi
}

echo "--------------------------------------------------------"
echo "Starting Cleanup for BASE_NAME: $BASE_NAME"
echo "--------------------------------------------------------"

# 1. Clean Raw FASTQs
confirm_and_run "${BASE_NAME}_fastqs" "Raw FASTQ files" "rm -rf ${BASE_NAME}_fastqs && echo 'Deleted raw fastqs.'"

# 1.1 Clean Merged FASTQs
confirm_and_run "${BASE_NAME}_merged" "Merged FASTQ files for xengsort" "rm -rf ${BASE_NAME}_merged && echo 'Deleted merged folder.'"

# 2. Clean Xengsort-classified FASTQs
confirm_and_run "${BASE_NAME}_classified" "Xengsort-classified FASTQ files" "rm -rf ${BASE_NAME}_classified && echo 'Deleted classified folder.'"

# 2.1 Thin out the Full Data Cell Ranger folder (The original unified run)
FULL_OUT_DIR="${BASE_NAME}_multi"
FULL_DEST_PATH="${FULL_OUT_DIR}/outs/per_sample_outs/${FULL_OUT_DIR}"

if [ -d "$FULL_OUT_DIR" ]; then
    echo "Thinning Full Data folder $FULL_OUT_DIR..."
    
    delete_full_extras() {
        # Move essential data to temp
        mv "$FULL_DEST_PATH" "./${FULL_OUT_DIR}_TEMP_KEEP"
        # Delete original (containing BAMs/logs/temps)
        rm -rf "$FULL_OUT_DIR"
        # Restore structure
        mkdir -p "$FULL_DEST_PATH"
        mv "./${FULL_OUT_DIR}_TEMP_KEEP"/* "$FULL_DEST_PATH/"
        rmdir "./${FULL_OUT_DIR}_TEMP_KEEP"
        echo "Thinned $FULL_OUT_DIR successfully."
    }

    confirm_and_run "$FULL_OUT_DIR" "Full data results (keeping only per-sample outs)" "delete_full_extras"
fi

# 3. Process Graft and Host specific folders
for TYPE in "${TYPES[@]}"; do
    INT_DIR="${BASE_NAME}_classified_${TYPE}"
    CR_OUT_DIR="${BASE_NAME}_${TYPE}_multi"

    # Specific destination path: ID/outs/per_sample_outs/ID/
    DEST_PATH="${CR_OUT_DIR}/outs/per_sample_outs/${CR_OUT_DIR}"

    if [ -d "$INT_DIR" ]; then
        echo "Processing $TYPE specific files..."

        # Move metadata to the deep Cell Ranger output folder
        if [ -d "$DEST_PATH" ]; then
            echo "Moving IDs and Config for $TYPE to $DEST_PATH"
            mv "${INT_DIR}/${TYPE}_ids.txt" "$DEST_PATH/" 2>/dev/null
            mv "${INT_DIR}/${BASE_NAME}_multi_config_${TYPE}.csv" "$DEST_PATH/" 2>/dev/null
        fi

        # Remove the intermediate folder
        confirm_and_run "$INT_DIR" "$TYPE-specific intermediate FASTQs" "rm -rf $INT_DIR && echo 'Deleted $INT_DIR folder.'"
    fi

    # 4. Thin out the classified Cell Ranger output folders
    if [ -d "$CR_OUT_DIR" ]; then
        echo "Thinning $CR_OUT_DIR (keeping only nested sample outs)..."

        delete_cr_extras() {
            mv "$DEST_PATH" "./${CR_OUT_DIR}_TEMP_KEEP"
            rm -rf "$CR_OUT_DIR"
            mkdir -p "$DEST_PATH"
            mv "./${CR_OUT_DIR}_TEMP_KEEP"/* "$DEST_PATH/"
            rmdir "./${CR_OUT_DIR}_TEMP_KEEP"
            echo "Thinned $CR_OUT_DIR successfully."
        }

        confirm_and_run "$CR_OUT_DIR" "$TYPE-specific Cell Ranger results" "delete_cr_extras"
    fi
done

# --- GZIP METADATA FILES ---
echo "--------------------------------------------------------"
echo "Compressing ID files..."
echo "--------------------------------------------------------"

for TYPE in "${TYPES[@]}"; do
    SAMPLE_ID="${BASE_NAME}_${TYPE}_multi"
    ID_FILE="${SAMPLE_ID}/outs/per_sample_outs/${SAMPLE_ID}/${TYPE}_ids.txt"

    if [ -f "$ID_FILE" ]; then
        gzip "$ID_FILE"
        echo "Compressed: $ID_FILE -> ${TYPE}_ids.txt.gz"
    fi
done

# Move job output and error files to logs
echo "--------------------------------------------------------"
echo "Moving log files..."
echo "--------------------------------------------------------"
LOG_DIR=logs/${BASE_NAME}
mkdir -p ${LOG_DIR}
mv *.out *.err ${LOG_DIR}/ 2>/dev/null
echo "Log files moved to ${LOG_DIR}"

echo "--------------------------------------------------------"
echo "Cleanup Process Finished."
echo "--------------------------------------------------------"
