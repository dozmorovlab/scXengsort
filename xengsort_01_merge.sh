#!/bin/bash
#SBATCH --job-name=xengsort_01_merge
#SBATCH --output=xengsort_01_merge.%j.out
#SBATCH --error=xengsort_01_merge.%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
# SBATCH --mem=10G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=xengsort_config.sh
source "${SCRIPT_DIR}/xengsort_config.sh"

mkdir -p "$MERGED_DIR"

echo "Merging R1..."
cat "${FASTQ_DIR}"/*_R1_*.fastq.gz > "${MERGED_DIR}/merged_R1.fastq.gz"
echo "Merging R2..."
cat "${FASTQ_DIR}"/*_R2_*.fastq.gz > "${MERGED_DIR}/merged_R2.fastq.gz"
echo "Merging I1..."
cat "${FASTQ_DIR}"/*_I1_*.fastq.gz > "${MERGED_DIR}/merged_I1.fastq.gz"
if compgen -G "${FASTQ_DIR}/*_I2_*.fastq.gz" > /dev/null; then
    echo "Merging I2..."
    cat "${FASTQ_DIR}"/*_I2_*.fastq.gz > "${MERGED_DIR}/merged_I2.fastq.gz"
else
    echo "No I2 FASTQs found; continuing with single-index data."
fi

echo "Merge complete."
