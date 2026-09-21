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

BASE_NAME="hgmm_12k" #  "5k_hgmm_3p_nextgem"
IN_DIR="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_fastqs"
OUT_DIR="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_merged"

mkdir -p $OUT_DIR

echo "Merging R1..."
cat ${IN_DIR}/*_R1_*.fastq.gz > ${OUT_DIR}/merged_R1.fastq.gz
echo "Merging R2..."
cat ${IN_DIR}/*_R2_*.fastq.gz > ${OUT_DIR}/merged_R2.fastq.gz
echo "Merging I1..."
cat ${IN_DIR}/*_I1_*.fastq.gz > ${OUT_DIR}/merged_I1.fastq.gz
echo "Merging I2..."
cat ${IN_DIR}/*_I2_*.fastq.gz > ${OUT_DIR}/merged_I2.fastq.gz

echo "Merge complete."
