#!/bin/bash
#SBATCH --job-name=xengsort_02_classify
#SBATCH --output=xengsort_02_classify.%j.out
#SBATCH --error=xengsort_02_classify.%j.err
#SBATCH --mail-user=mdozmorov@vcu.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=cpu
#SBATCH --mem=100G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32

module load miniconda3
conda activate xengsort

module load htslib
module load samtools

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=xengsort_config.sh
source "${SCRIPT_DIR}/xengsort_config.sh"

mkdir -p "$CLASSIFIED_DIR"

xengsort classify \
  --index "$XENGSORT_INDEX" \
  -q "${MERGED_DIR}/merged_R1.fastq.gz" \
  -p "${MERGED_DIR}/merged_R2.fastq.gz" \
  -o "$CLASSIFIED_DIR" \
  -T "$SLURM_CPUS_PER_TASK" \
  --progress
#  --compression gz 

mv "${CLASSIFIED_DIR}"*.fq.gz "$CLASSIFIED_DIR/"
