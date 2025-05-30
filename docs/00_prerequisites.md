# Prerequisites

Before running the gVCF processing pipeline, ensure your system meets the following requirements:

## Software Requirements

1.  **Linux Environment:**
    *   The script is designed for a BASH shell, commonly found in Linux distributions.
    *   **WSL (Windows Subsystem for Linux):** If you are on Windows, install WSL and a Linux distribution like Ubuntu. See [Microsoft's WSL Installation Guide](https://learn.microsoft.com/en-us/windows/wsl/install).
    *   **macOS:** The built-in terminal uses zsh or bash and should work.
    *   **Native Linux:** Any standard Linux distribution.

2.  **`bcftools`:**
    *   This is the primary tool used for VCF/gVCF manipulation.
    *   Version 1.9 or newer is recommended. Some older versions might have different behavior or lack certain features.
    *   **Installation (Recommended: Conda/Mamba):**
        The easiest way to install `bcftools` and manage its dependencies is through Conda or Mamba (a faster Conda alternative).
        ```bash
        # 1. Install Miniconda (https://docs.conda.io/en/latest/miniconda.html) or Anaconda.
        # 2. Create a dedicated environment (recommended):
        conda create -n bcftools_env
        conda activate bcftools_env
        # 3. Install bcftools from bioconda and conda-forge channels:
        conda install -c bioconda -c conda-forge bcftools
        ```
    *   **Check `bcftools` installation:**
        ```bash
        bcftools --version
        ```

3.  **Standard Unix Utilities:**
    The script uses common utilities like `seq`, `sed`, `ls`, `head`, `od`, `mkdir`, `basename`, `cat`. These are typically pre-installed on most Linux systems and macOS.

## System Requirements

1.  **Disk Space:**
    *   Sufficient space for your input gVCF files.
    *   Space for intermediate filtered gVCF files (stored in `filtered_gvcfs_autosomes/`). These will be similar in size to the input files but restricted to autosomes.
    *   Space for the final merged VCF (`merged.pass.chrs1-22.vcf.gz`), which can be significantly larger than individual gVCFs, depending on the number of samples and variant density.
    *   Consider having at least 2-3 times the total size of your input gVCFs available.

2.  **Memory (RAM):**
    *   The `bcftools merge` step can be memory-intensive, especially with a large number of samples.
    *   The exact requirement depends on the number of samples and the complexity of the gVCFs. For dozens of samples, 16-32GB RAM might be a reasonable starting point. For hundreds, more will be needed.
    *   The script processes files individually for chromosome filtering, which is less memory-intensive than the merge step.

## User Permissions

*   You need write permissions in the directory where you run the script to create output files and directories.
*   You need read permissions for the input gVCF files. 