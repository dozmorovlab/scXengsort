# Xengsort pipeline for PDX scRNA-seq

Slide 32 at https://docs.google.com/presentation/d/1oPQnh1rn7WNHmKliPG-YrfcdXCY-vxotibf4Bd6wYqY/edit?slide=id.g3b5d7cbd387_1_0&pli=1#slide=id.g3b5d7cbd387_1_0

scp "mdozmorov@athena.hprc.vcu.edu:/lustre/home/juicer/MultipletR.dev/xengsort_0*.sh" .

The initial FASTQ files should be in a folder `${BASE_NAME}_fastqs`, where `${BASE_NAME}` is the unique identifier for the dataset. It will be used to name the following folders.

- `xengsort_00_cellranger_full.sh` - Cellranger multi pipeline using the barnyard reference
  - Input: Configuration file `${BASE_NAME}_full_multi_config.csv"` created by the script, pointing to the downloaded FASTQ files that should be saved in in `${BASE_NAME}_fastqs`
  - Output: `${BASE_NAME}_multi` with Celltanger's output

- `xengsort_01_merge.sh` - Merge all R1/R2 I1/I2 files. Barcodes are spread across lanes and need to be merged. Fast
  - Input: Input FASTQ directory, `${BASE_NAME}_fastqs`
  - Output: Output directory `${BASE_NAME}_merged`. File names like `merged_R1.fastq.gz`, `merged_I1.fastq.gz`

- `xengsort_02_classify.sh` - xengsort classification. Only R1/R2 reads are classified. xengsort must be installed in a conda enfironment. Fast
  - Input: Merged FASTQ directory `${BASE_NAME}_merged`.
  - Output: Output directory `${BASE_NAME}_classified`. File names defined using BASE_NAME "_classified" prefix and graft/host/both/neither suffixes, 1/2 paired end, .fq.gz

- `xengsort_03_subset.sh` - subset index files by barcodes extracted from graft/host-classified files. seqkit should be installed. This and the following files should be run separately for TYPE="graft" and TYPE="host" setting. Medium time
  - Input: Index files from the `${BASE_NAME}_merged` folder. Barcodes are extracted from a `${BASE_NAME}_classified-${TYPE}.1.fq.gz` file from the `${BASE_NAME}_classified` folder. `$TYPE` defines whether "graft" or "host"-specific FASTQ files should be processed.
  - Output: Output directory defined by ${BASE_NAME}_classified_${TYPE}
    - Output: `${TYPE}_ids.txt` - barcodes extracted from the TYPE-specific file.
    - Output: `${BASE_NAME}_classified-${TYPE}.I1.fq.gz` and same for I2 - subsetted index files. If the data has one index file, the second will be created as empty and must be deleted manually.

- `xengsort_04_sort.sh` - Sorting 1/2 read files and I1/I2 index files alphabetically so the order of barcodes match. Needed as multithreaded subsetting breaks the order. Also checks if the number of barcodes in `${TYPE}_ids.txt` and in the subsetted files is identical. Long time
  - Input: Directory defined by ${BASE_NAME}_classified_${TYPE}, files like `${BASE_NAME}_classified-${TYPE}.1.fq.gz`
  - Output: Sorted files with the "sorted_" prefix in the same directory

- `xengsort_05_prepare.sh` - Rename files into CellRanger-compatible file names. Also generates the configuration file for Cellranger multi. Fast
  - Input: Files like `sorted_${BASE_NAME}_classified-${TYPE}.1.fq.gz` from ${BASE_NAME}_xengsort_${TYPE} folder
  - Output: Renamed files like `${SAMPLE_ID}_S1_L001_R1_001.fastq.gz` in the same folder. SAMPLE_ID="${BASE_NAME}_${TYPE}"
  - Output: Configuration file like `${BASE_NAME}_multi_config_graft.csv"`

- `xengsort_06_cellranger.sh` - cellranger multi pipeline on classified, sorted, and renamed files. Fast
  - Input: Configuration file like `${BASE_NAME}_multi_config_graft.csv"` pointing to the FASTQ files, created by the script.
  - Output: `${BASE_NAME}_${TYPE}_multi` directory

- `xengsort_07_cleanup.sh` - Removing intermediate files - raw, merged, classified/sorted FASTQs, thinning the Cellranger's multi folders to keep only the per sample output. Gzipping large files. Requires confirmation of each step. Non-SLURM, must be run interactively.

## Xengsort Processed data

+ 5k_hgmm_3p_nextgem_graft_multi
<!--5k_hgmm_5p_nextgem_graft_multi-->
+ 10k_hgmm_3p_gemx_fastqs 
+ hgmm_6k
+ hgmm_12k_graft_multi
+ PC65
+ PC67
+ VCU-CO-063_1805_graft_multi
+ VCU-BC-037_110509_graft_multi
<!--VCU-BC-043_110216_graft_multi-->
+ VCU-BC-074_1929_graft_multi

/global/projects/harrell_projects/scRNASeq/raw/NextSeq241009/
VCU-PC-062_1803
VCU-PC-075_1836

/global/projects/harrell_projects/scRNASeq/raw/NextSeq241025/
VCU-BC-037_110509
