# merge_gvcf

This repository provides a BASH script and guidelines for processing multiple gVCF (genomic VCF) files. The pipeline performs the following key steps:
This pipeline is suitable for merging and then filtering. For filtering for PASS and then merging files visit GVCF_Pipeline_Solution folder.
1.  Filters each input gVCF to retain only autosomal chromosomes (`chr1` through `chr22`).
2.  Merges these filtered gVCFs into a single cohort gVCF.
3.  Filters the merged cohort gVCF to keep only variants with a `PASS` status in the FILTER column.
4.  Outputs a final, indexed, gzipped VCF (`merged.pass.chrs1-22.vcf.gz`).

This pipeline is designed to be run in a Linux environment, preferably within WSL (Windows Subsystem for Linux) if on Windows, and requires `bcftools`.

## Table of Contents

*   [Quick Start](#quick-start)
*   [Prerequisites](#prerequisites)
*   [Input Files](#input-files)
*   [Running the Pipeline](#running-the-pipeline)
*   [Script Overview](#script-overview)
*   [Expected Output](#expected-output)
*   [Customization](#customization)
*   [Troubleshooting](#troubleshooting)
*   [Contributing](#contributing)

## Quick Start

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/ssaglam2/merge_gvcf.git
    cd merge_gvcf
    ```
2.  **Place your input gVCF files** (e.g., `*.hard-filtered.gvcf.gz`) into the main project directory.
3.  **Ensure `bcftools` is installed** and accessible (e.g., via a Conda environment).
4.  **Make the script executable:**
    ```bash
    chmod +x run_gvcf_pipeline.sh
    ```
5.  **Activate your Conda environment (if applicable):**
    ```bash
    conda activate <your_conda_env_name> # e.g., bio_env
    ```
6.  **Run the pipeline:**
    ```bash
    ./run_gvcf_pipeline.sh
    ```

## Prerequisites

*   **Linux Environment:** WSL (e.g., Ubuntu) on Windows, or a native Linux system.
*   **BASH Shell:** The script is written for BASH.
*   **`bcftools`:** Version 1.9 or higher recommended. (Installation via Conda/Mamba is advised).
    ```bash
    # Example Conda installation:
    # conda create -n bcftools_env -c bioconda -c conda-forge bcftools
    # conda activate bcftools_env
    ```
*   **Sufficient Disk Space:** For intermediate files and the final merged VCF.
*   **Sufficient RAM:** `bcftools merge` can be memory-intensive.

See [docs/00_prerequisites.md](./docs/00_prerequisites.md) for more details.

## Input Files

*   Multiple gzipped gVCF files (e.g., `sampleA.hard-filtered.gvcf.gz`, `sampleB.hard-filtered.gvcf.gz`, etc.) located in the same directory as the `run_gvcf_pipeline.sh` script.
*   The script assumes these files end with `.hard-filtered.gvcf.gz`. This pattern is used to automatically generate `gvcf_list.txt` if it doesn't exist.
*   Input gVCFs should use chromosome names with the "chr" prefix (e.g., `chr1`, `chr2`).

See [docs/01_input_files.md](./docs/01_input_files.md) for more details.

## Running the Pipeline

1.  Navigate to the project directory in your terminal.
2.  Ensure your input gVCF files are present.
3.  Activate your Conda environment containing `bcftools` if necessary.
4.  Execute the script: `./run_gvcf_pipeline.sh`

The script will:
    *   Create `standard_chroms.txt` (listing `chr1` to `chr22`).
    *   Create `gvcf_list.txt` if it doesn't exist (listing your input gVCFs).
    *   Create a subdirectory `filtered_gvcfs_autosomes/` for intermediate files.
    *   Process each gVCF, filter by autosomes, and save to the subdirectory.
    *   Merge the filtered gVCFs.
    *   Filter the merged result for `PASS` variants.
    *   Save the final output as `merged.pass.chrs1-22.vcf.gz` and its index.

## Script Overview

The `run_gvcf_pipeline.sh` script automates the entire workflow. Key steps include:
*   Configuration of file and directory names.
*   Creation of a helper file (`standard_chroms.txt`) listing target chromosomes.
*   Generation of a list of input gVCFs (`gvcf_list.txt`).
*   Looping through each input gVCF to filter for autosomal regions using `bcftools view -t ^standard_chroms.txt`.
*   Indexing these intermediate filtered files.
*   Merging the intermediate files using `bcftools merge --gvcf`.
*   Filtering the merged output for `PASS` variants using `bcftools view -f PASS`.
*   Indexing the final output VCF.

See [docs/02_script_explanation.md](./docs/02_script_explanation.md) for a detailed breakdown.

## Expected Output

*   **`standard_chroms.txt`**: List of chromosomes `chr1` to `chr22`.
*   **`gvcf_list.txt`**: List of your input gVCF files.
*   **`filtered_gvcfs_autosomes/`**: Directory containing gVCFs filtered for autosomes.
*   **`filtered_gvcf_list_autosomes.txt`**: List of paths to the files in `filtered_gvcfs_autosomes/`.
*   **`merged.pass.chrs1-22.vcf.gz`**: The final gzipped VCF containing merged, PASS-filtered variants for autosomes.
*   **`merged.pass.chrs1-22.vcf.gz.tbi`**: The Tabix index for the final VCF.

## Customization

The script can be customized for different needs:
*   Changing the input file pattern.
*   Including sex chromosomes or mitochondrial DNA.
*   Modifying output filenames.

See [docs/03_customization.md](./docs/03_customization.md) for guidance.

## Troubleshooting

Common issues and their solutions are discussed here:
*   `bcftools: command not found`
*   Errors related to file parsing or incorrect chromosome names.
*   Permissions issues.

See [docs/04_troubleshooting.md](./docs/04_troubleshooting.md) for details.

## Contributing

Contributions, bug reports, and suggestions are welcome! Please open an issue or submit a pull request. 
