#!/bin/bash
# Shared settings for the Xengsort PDX scRNA-seq pipeline.
#
# Edit values in this file for a new dataset or installation. Any setting can
# also be overridden for one invocation, for example:
# BASE_NAME=my_sample sbatch xengsort_01_merge.sh

BASE_NAME="${BASE_NAME:-hgmm_12k}"
PROJECT_ROOT="${PROJECT_ROOT:-/lustre/home/juicer/MultipletR.dev}"

CELLRANGER_BIN="${CELLRANGER_BIN:-${PROJECT_ROOT}/cellranger-10.0.0/bin/cellranger}"
XENGSORT_INDEX="${XENGSORT_INDEX:-/lustre/home/juicer/ExtData/xengsort_refs/myindex}"
SEQKIT_BIN="${SEQKIT_BIN:-seqkit}"

HUMAN_REFERENCE="${HUMAN_REFERENCE:-/lustre/home/juicer/ExtData/10x/refdata-gex-GRCh38-2024-A}"
MOUSE_REFERENCE="${MOUSE_REFERENCE:-/lustre/home/juicer/ExtData/10x/refdata-gex-GRCm39-2024-A}"
MIXED_REFERENCE="${MIXED_REFERENCE:-/lustre/home/juicer/ExtData/10x/refdata-gex-GRCh38_and_GRCm39-2024-A}"

CLASSIFICATION_TYPES=(graft host ambiguous neither)

FASTQ_DIR="${PROJECT_ROOT}/${BASE_NAME}_fastqs"
MERGED_DIR="${PROJECT_ROOT}/${BASE_NAME}_merged"
CLASSIFIED_DIR="${PROJECT_ROOT}/${BASE_NAME}_classified"
FULL_MULTI_CONFIG="${PROJECT_ROOT}/${BASE_NAME}_full_multi_config.csv"
FULL_MULTI_OUTPUT="${BASE_NAME}_multi"
LOG_DIR="${PROJECT_ROOT}/logs/${BASE_NAME}"
# Cell Ranger outputs are written directly under PROJECT_ROOT by steps 00 and 06.
REPORT_OUTPUT_ROOT="${REPORT_OUTPUT_ROOT:-${PROJECT_ROOT}}"

classified_type_dir() {
    printf '%s/%s_classified_%s\n' "$PROJECT_ROOT" "$BASE_NAME" "$1"
}

cellranger_reference_for_type() {
    case "$1" in
        graft) printf '%s\n' "$HUMAN_REFERENCE" ;;
        host) printf '%s\n' "$MOUSE_REFERENCE" ;;
        *) printf '%s\n' "$MIXED_REFERENCE" ;;
    esac
}
