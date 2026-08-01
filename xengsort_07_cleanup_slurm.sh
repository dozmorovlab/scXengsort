#!/bin/bash
#SBATCH --job-name=xengsort_07_cleanup
#SBATCH --output=xengsort_07_cleanup_%j.out
#SBATCH --error=xengsort_07_cleanup_%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
# SBATCH --mem=100G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12

# --- CONFIGURATION ---
BASE_NAME="VCU-PC-067_1823" # "VCU-PC-065_1815" #  "hgmm_6k" # "10k_hgmm_3p_gemx" "VCU-CO-063_1805" #  "VCU-BC-074_1929" #  "VCU-BC-043_110216" #  "VCU-BC-037_110509"
PROJECT_ROOT="/lustre/home/juicer/MultipletR.dev"
# DELETE_ALL is effectively true by default in this non-interactive script
TYPES=( "graft" "host" "ambiguous" "neither" )

# Ensure we are in the correct directory
cd "$PROJECT_ROOT" || { echo "Error: Could not change to $PROJECT_ROOT"; exit 1; }

# Function for automated execution (Replaces confirm_and_run)
run_step() {
    local folder=$1
    local message=$2
    local cmd=$3

    if [ ! -d "$folder" ]; then
        echo "Skipping: $folder (not found)"
        return
    fi

    echo "Processing: $folder ($message)..."
    # Execute the command passed as a string
    eval "$cmd"
}

echo "--------------------------------------------------------"
echo "Starting Automated Cleanup for BASE_NAME: $BASE_NAME"
echo "Date: $(date)"
echo "--------------------------------------------------------"

# 1. Clean Raw FASTQs
# run_step "${BASE_NAME}_fastqs" "Raw FASTQ files" "rm -rf ${BASE_NAME}_fastqs && echo 'Deleted raw fastqs.'"

# 1.1 Clean Merged FASTQs
run_step "${BASE_NAME}_merged" "Merged FASTQ files for xengsort" "rm -rf ${BASE_NAME}_merged && echo 'Deleted merged fastqs.'"

# 2. Clean Xengsort-classified FASTQs
run_step "${BASE_NAME}_classified" "Xengsort-classified FASTQ files" "rm -rf ${BASE_NAME}_classified && echo 'Deleted classified fastqs.'"

# 2.1 Thin out the Full Data Cell Ranger folder (The original unified run)
FULL_OUT_DIR="${BASE_NAME}_multi"
FULL_DEST_PATH="${FULL_OUT_DIR}/outs/per_sample_outs/${FULL_OUT_DIR}"

if [ -d "$FULL_OUT_DIR" ]; then
    echo "Thinning Full Data folder $FULL_OUT_DIR..."

    # Define function locally to capture variables
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

    # Execute immediately
    delete_full_extras
else
    echo "Skipping $FULL_OUT_DIR (not found)"
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
        run_step "$INT_DIR" "$TYPE-specific intermediate FASTQs" "rm -rf $INT_DIR && echo 'Deleted $INT_DIR folder.'"
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

        # Execute immediately
        delete_cr_extras
    else
        echo "Skipping $CR_OUT_DIR (not found)"
    fi
done

# --- GZIP METADATA FILES ---
echo "--------------------------------------------------------"
echo "Deleting ID files..."
echo "--------------------------------------------------------"

for TYPE in "${TYPES[@]}"; do
    SAMPLE_ID="${BASE_NAME}_${TYPE}_multi"
    ID_FILE="${SAMPLE_ID}/outs/per_sample_outs/${SAMPLE_ID}/${TYPE}_ids.txt"

    if [ -f "$ID_FILE" ]; then
        rm "$ID_FILE"
        echo "Deleted: $ID_FILE -> ${TYPE}_ids.txt.gz"
    fi
done

# Move job output and error files to logs
echo "--------------------------------------------------------"
echo "Moving log files..."
echo "--------------------------------------------------------"
LOG_DIR="logs/${BASE_NAME}"
mkdir -p "${LOG_DIR}"

# Note: Moving the current job's .out/.err file while it is running 
# is usually fine, but the very last lines of echo might not appear in the moved file.
# We sleep briefly to ensure file handle stability.
sleep 2

mv "cleanup_${SLURM_JOB_ID}.out" "${LOG_DIR}/" 2>/dev/null
mv "cleanup_${SLURM_JOB_ID}.err" "${LOG_DIR}/" 2>/dev/null
# Also move any previous ones matching the pattern just in case
mv *.out *.err "${LOG_DIR}/" 2>/dev/null

echo "Log files moved to ${LOG_DIR}"

echo "--------------------------------------------------------"
echo "Cleanup Process Finished."
echo "--------------------------------------------------------"
