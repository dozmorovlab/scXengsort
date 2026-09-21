# Xengsort pipeline for PDX scRNA-seq

PDX (patient-derived xenograft) 10x scRNA-seq libraries contain a mix of
human graft (tumor) and mouse host (stroma) cells, so reads must be split
by species of origin before quantification. This pipeline uses
[xengsort](https://gitlab.com/genomeinformatics/xengsort) to classify each
read pair as `graft` (human), `host` (mouse), `ambiguous`, or `neither`,
regenerates CellRanger-compatible FASTQs for each class, and quantifies
them separately with `cellranger multi`. A companion "barnyard" run
(combined human+mouse reference, no xengsort) is used as an independent
ground truth to check how well xengsort-based read classification agrees
with CellRanger's own per-barcode multiplet (doublet) calls.

The original manually developed scripts are preserved on the
[`manual`](https://github.com/dozmorovlab/scXengsort/tree/manual) branch.

## Configuration

All shared pipeline settings are in [`xengsort_config.sh`](xengsort_config.sh):
the dataset identifier, project and report-output roots, Cell Ranger and
seqkit executables, xengsort index, references, and classification types.
Edit that file once before submitting any pipeline script. Its settings may
also be overridden for an individual job, for example
`BASE_NAME=my_sample sbatch xengsort_01_merge.sh`. Slurm resource directives
remain in their respective scripts because Slurm reads those before Bash can
load the shared configuration.

Place initial FASTQ files in `${BASE_NAME}_fastqs`, where `${BASE_NAME}` is
configured in `xengsort_config.sh` and uniquely identifies the dataset.

## Pipeline steps

- `xengsort_00_cellranger_full.sh` - Cell Ranger `multi` pipeline using the
  barnyard reference. It provides `gem_classification.csv` for comparison
  with xengsort-based multiplet calls.
  - Input: FASTQs in `${BASE_NAME}_fastqs`; the script creates
    `${BASE_NAME}_full_multi_config.csv`.
  - Output: `${BASE_NAME}_multi` with Cell Ranger output.

- `xengsort_01_merge.sh` - Merges lane-level R1/R2/I1 FASTQs and I2 when
  supplied. Barcodes spread across lanes must be merged before
  classification.
  - Input: `${BASE_NAME}_fastqs`.
  - Output: `${BASE_NAME}_merged`, including `merged_R1.fastq.gz` and
    `merged_I1.fastq.gz`.

- `xengsort_02_classify.sh` - Classifies R1/R2 reads with
  [xengsort](https://gitlab.com/genomeinformatics/xengsort), which must be
  available in the activated Conda environment.
  - Input: `${BASE_NAME}_merged`.
  - Output: `${BASE_NAME}_classified`, with paired FASTQs for `graft`,
    `host`, `ambiguous`, and `neither`.

- `xengsort_03_subset.sh` - Subsets index FASTQs using IDs extracted from
  classified reads. [seqkit](https://github.com/shenwei356/seqkit) must be
  available on `PATH`.
  - Input: index FASTQs from `${BASE_NAME}_merged` and classified R1 reads
    from `${BASE_NAME}_classified`.
  - Output: Output directory defined by `${BASE_NAME}_classified_${TYPE}`
    - Output: `${TYPE}_ids.txt` - barcodes extracted from the TYPE-specific file.
    - Output: `${BASE_NAME}_classified-${TYPE}.I1.fq.gz` and, when present in the input, the corresponding I2 file. R1/R2 files are linked rather than copied to avoid duplicating large FASTQs.

- `xengsort_04_sort.sh` - Sorts R1/R2/I1 and optional I2 FASTQs
  alphabetically so their barcode order matches after multithreaded
  subsetting. It also compares each read count with `${TYPE}_ids.txt`.
  - Input: Directory defined by `${BASE_NAME}_classified_${TYPE}`, files like `${BASE_NAME}_classified-${TYPE}.1.fq.gz`. I2 is processed only when present.
  - Output: Sorted files with the "sorted_" prefix in the same directory

- `xengsort_05_prepare.sh` - Renames files to Cell Ranger-compatible names
  and generates a `multi` configuration file.
  - Input: Files like `sorted_${BASE_NAME}_classified-${TYPE}.1.fq.gz` from `${BASE_NAME}_classified_${TYPE}` folder. I2 is optional.
  - Output: Renamed files like `${SAMPLE_ID}_S1_L001_R1_001.fastq.gz` in the same folder. SAMPLE_ID="${BASE_NAME}_${TYPE}"
  - Output: Configuration file like `${BASE_NAME}_multi_config_graft.csv`.

- `xengsort_06_cellranger.sh` - Runs Cell Ranger `multi` on classified,
  sorted, and renamed files.
  - Input: A configuration file such as
    `${BASE_NAME}_multi_config_graft.csv` created by the preceding script.
  - Output: `${BASE_NAME}_${TYPE}_multi` directory

- `xengsort_07_cleanup.sh` - Removes intermediate FASTQs and thins Cell Ranger
  output to per-sample results. It is interactive and must be run outside
  Slurm. `xengsort_07_cleanup_slurm.sh` provides the non-interactive,
  Slurm-batchable equivalent.

- `xengsort_08_check.Rmd` - Final validation of xengsort barcode
  classification against Cell Ranger barnyard multiplet calls.
  - Input: `sample_filtered_feature_bc_matrix` output from the graft and
    host Cell Ranger runs. A barcode is `GRCh38` if only in graft, `GRCm39`
    if only in host, and `Multiplet` if in both.
  - Input: `gem_classification.csv` from the full-data barnyard Cell Ranger
    `multi` run.
  - Logic: compares classifications through Euler diagrams, read-depth versus
    mouse-read scatterplots, optional ambiguous/neither results, and
    count-matrix summaries.
  - Usage: configure `REPORT_OUTPUT_ROOT` and `BASE_NAME` in `xengsort_config.sh`, then knit from the directory containing that file. Requires `Seurat`, `tidyverse`, `eulerr`, `gridExtra`, `patchwork`, `pander`, `knitr`.
