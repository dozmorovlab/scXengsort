# Xengsort pipeline for PDX scRNA-seq
<!-- https://claude.ai/chat/08c859fb-b4ca-4544-a1f7-37f5dcbd22da -->
<!-- scp "mdozmorov@athena.hprc.vcu.edu:/lustre/home/juicer/MultipletR.dev/xengsort_0*.sh" . -->

PDX (patient-derived xenograft) 10x scRNA-seq libraries contain a mix of
human graft (tumor) and mouse host (stroma) cells, so reads must be split
by species of origin before quantification. This pipeline uses
[xengsort](https://gitlab.com/genomeinformatics/xengsort) to classify each
read pair as `graft` (human), `host` (mouse), `ambiguous`, or `neither`,
regenerates CellRanger-compatible FASTQs for each class, and quantifies
them separately with `cellranger multi`. A companion "barnyard" run
(combined human+mouse reference, no xengsort) is used as an independent
ground truth to check how well xengsort-based read classification agrees
with CellRanger's own per-barcode multiplet (doublet) calls. See the 
[manual](https://github.com/dozmorovlab/scXengsort/tree/manual) branch for 
the manually developed scripts.

The initial FASTQ files should be in a folder `${BASE_NAME}_fastqs`, where `${BASE_NAME}` is the unique identifier for the dataset. It will be used to name the following folders.

- `xengsort_00_cellranger_full.sh` - Cellranger multi pipeline using the barnyard reference. Used for comparison of 10x-classified multiplets in the `gem_classification.csv` file.
  - Input: Configuration file `${BASE_NAME}_full_multi_config.csv"` created by the script, pointing to the downloaded FASTQ files that should be saved in in `${BASE_NAME}_fastqs`
  - Output: `${BASE_NAME}_multi` with Cellranger's output

- `xengsort_01_merge.sh` - Merge all R1/R2 I1/I2 files. Barcodes are spread across lanes and need to be merged. Fast step.
  - Input: Input FASTQ directory, `${BASE_NAME}_fastqs`
  - Output: Output directory `${BASE_NAME}_merged`. File names like `merged_R1.fastq.gz`, `merged_I1.fastq.gz`

- `xengsort_02_classify.sh` - [xengsort](https://gitlab.com/genomeinformatics/xengsort) classification. Only R1/R2 reads are classified. xengsort must be installed in a conda enfironment. Fast step.
  - Input: Merged FASTQ directory `${BASE_NAME}_merged`.
  - Output: Output directory `${BASE_NAME}_classified`. File names defined using BASE_NAME "_classified" prefix and graft/host/both/neither suffixes, 1/2 paired end, .fq.gz

- `xengsort_03_subset.sh` - subset index files by barcodes extracted from graft/host-classified files. [seqkit](https://github.com/shenwei356/seqkit) should be installed. This and the following files should be run separately for TYPE="graft" and TYPE="host" setting. Medium time
  - Input: Index files from the `${BASE_NAME}_merged` folder. Barcodes are extracted from a `${BASE_NAME}_classified-${TYPE}.1.fq.gz` file from the `${BASE_NAME}_classified` folder. `$TYPE` defines whether "graft" or "host"-specific FASTQ files should be processed.
  - Output: Output directory defined by ${BASE_NAME}_classified_${TYPE}
    - Output: `${TYPE}_ids.txt` - barcodes extracted from the TYPE-specific file.
    - Output: `${BASE_NAME}_classified-${TYPE}.I1.fq.gz` and same for I2 - subsetted index files. If the data has one index file, the second will be created as empty and must be deleted manually.

- `xengsort_04_sort.sh` - Sorting 1/2 read files and I1/I2 index files alphabetically so the order of barcodes match. Needed as multithreaded subsetting breaks the order. Also checks if the number of barcodes in `${TYPE}_ids.txt` and in the subsetted files is identical. Long step.
  - Input: Directory defined by ${BASE_NAME}_classified_${TYPE}, files like `${BASE_NAME}_classified-${TYPE}.1.fq.gz`
  - Output: Sorted files with the "sorted_" prefix in the same directory

- `xengsort_05_prepare.sh` - Rename files into CellRanger-compatible file names. Also generates the configuration file for Cellranger multi. Fast step.
  - Input: Files like `sorted_${BASE_NAME}_classified-${TYPE}.1.fq.gz` from ${BASE_NAME}_xengsort_${TYPE} folder
  - Output: Renamed files like `${SAMPLE_ID}_S1_L001_R1_001.fastq.gz` in the same folder. SAMPLE_ID="${BASE_NAME}_${TYPE}"
  - Output: Configuration file like `${BASE_NAME}_multi_config_graft.csv"`

- `xengsort_06_cellranger.sh` - cellranger multi pipeline on classified, sorted, and renamed files. Fast step.
  - Input: Configuration file like `${BASE_NAME}_multi_config_graft.csv"` pointing to the FASTQ files, created by the script.
  - Output: `${BASE_NAME}_${TYPE}_multi` directory

- `xengsort_07_cleanup.sh` - Removing intermediate files - raw, merged, classified/sorted FASTQs, thinning the Cellranger's multi folders to keep only the per sample output. Gzipping large files. Requires confirmation of each step. Non-SLURM, must be run interactively. (`xengsort_07_cleanup_slurm.sh` is the same logic made non-interactive/SLURM-batchable, e.g. for use on an HPC login-less cleanup job.)

- `xengsort_08_check.Rmd` - Final validation step: checks how well xengsort-based barcode classification (from separate graft/host CellRanger runs) agrees with CellRanger's own barnyard multiplet classification.
  - Input: per-sample `sample_filtered_feature_bc_matrix` output from the graft (`_graft_multi`) and host (`_host_multi`) CellRanger runs (steps `05`-`06`) - a barcode is called `GRCh38` if seen only in the graft matrix, `GRCm39` if seen only in the host matrix, and `Multiplet` if seen in both.
  - Input: `gem_classification.csv` from the full-data barnyard `cellranger multi` run (step `00`) - CellRanger's own per-barcode `call`.
  - Logic: compares the two classifications via Euler diagrams (overall, and per class `GRCh38`/`GRCm39`/`Multiplet`) and total-reads-vs-percent-mouse scatterplots highlighting multiplets from each method; extends the comparison to the `ambiguous`/`neither` xengsort classes if those CellRanger runs exist; reports basic count-matrix statistics (dimensions, sparsity, count distribution) for every dataset loaded.
  - Usage: edit `base_dir` and `base_type` in the "Configuration" chunk near the top to point at your project folder and sample ID (matches `${BASE_NAME}` in the `xengsort_0*.sh` scripts), then knit to HTML. Requires `Seurat`, `tidyverse`, `eulerr`, `gridExtra`, `patchwork`, `pander`, `knitr`.
