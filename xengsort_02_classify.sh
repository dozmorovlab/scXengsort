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

BASE_NAME="hgmm_12k" #  "5k_hgmm_3p_nextgem"
DATA_DIR="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_merged"
INDEX="/lustre/home/juicer/ExtData/xengsort_refs/myindex" # Path to index created earlier
OUT_PREFIX="/lustre/home/juicer/MultipletR.dev/${BASE_NAME}_classified"

mkdir -p ${OUT_PREFIX}

xengsort classify \
  --index $INDEX \
  -q ${DATA_DIR}/merged_R1.fastq.gz \
  -p ${DATA_DIR}/merged_R2.fastq.gz \
  -o $OUT_PREFIX \
  -T 32 \
  --progress
#  --compression gz 

mv ${OUT_PREFIX}*.fq.gz ${OUT_PREFIX}/
