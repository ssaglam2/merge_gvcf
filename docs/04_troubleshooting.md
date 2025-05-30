# Troubleshooting Guide

This page lists common issues encountered while running the gVCF processing pipeline and their potential solutions.

## 1. `bcftools: command not found` or Script Errors Related to `bcftools`

*   **Cause:** `bcftools` is either not installed, or its location is not in your system's `PATH` environment variable, or your Conda environment (if used) is not activated.
*   **Solution:**
    1.  **Verify Installation:** Ensure `bcftools` is installed. See [Prerequisites](./00_prerequisites.md).
    2.  **Activate Conda Environment:** If you installed `bcftools` in a Conda environment (e.g., `bcftools_env`), make sure to activate it before running the script:
        ```bash
        conda activate bcftools_env # Or your environment name
        ./run_gvcf_pipeline.sh
        ```
    3.  **Check PATH:** If installed manually (not via Conda), ensure the directory containing the `bcftools` executable is in your `PATH`.

## 2. Error: `Failed to create or populate gvcf_list.txt`

*   **Cause:** The script could not find any files matching the default pattern `*.hard-filtered.gvcf.gz` in the current directory, or it failed to write `gvcf_list.txt`.
*   **Solution:**
    1.  **Check File Location:** Ensure your input gVCF files are in the same directory where you are running `run_gvcf_pipeline.sh`.
    2.  **Check File Naming:** Verify your gVCF files match the expected pattern (`*.hard-filtered.gvcf.gz`). If not, either rename your files, modify the script (see [Customization](./03_customization.md)), or manually create `gvcf_list.txt`.
    3.  **Permissions:** Ensure you have write permissions in the current directory to create `gvcf_list.txt`.

## 3. `bcftools view` Fails with Errors like `Could not parse ... regions file` or `Failed to read regions` (Even if `-t ^` is used)

While using `-t ^standard_chroms.txt` fixed the initial parsing error for `standard_chroms.txt`, other region-related issues can arise:

*   **Cause A: Mismatch in Chromosome Naming Convention:**
    *   The `standard_chroms.txt` file (e.g., using `chr1`, `chr2`) does not match the chromosome names in your actual VCF files (e.g., they might use `1`, `2` without "chr").
*   **Solution A:**
    1.  Inspect chromosome names in one of your VCFs:
        ```bash
        zcat YOUR_INPUT_FILE.g.vcf.gz | grep -v "^##" | cut -f1 | grep -v "^#" | sort | uniq | head
        ```
    2.  Modify Step 0 in `run_gvcf_pipeline.sh` to generate `standard_chroms.txt` with the correct naming convention (see [Customization](./03_customization.md)).

*   **Cause B: Corrupted Input gVCF File(s):**
    *   One or more of your input gVCF files might be corrupted or improperly formatted, causing `bcftools` to fail when trying to access specific regions.
*   **Solution B:**
    1.  Try to validate the problematic gVCF file using `bcftools stats` or by simply trying to view its header:
        ```bash
        bcftools view -h PROBLEMATIC_FILE.g.vcf.gz > /dev/null
        ```
        If this command fails, the VCF file itself has issues.
    2.  Re-generate the problematic gVCF if possible.

*   **Cause C: Issues with Input File Indexing (Less likely with this script)**
    *   The script indexes intermediate files. If this indexing step fails for some reason (e.g., disk full during indexing, corrupted intermediate VCF), `bcftools merge` might fail.
*   **Solution C:** Check script output for errors during the `bcftools index` commands in Step 3.

## 4. Script Fails with "Permission denied"

*   **Cause:** The script or `bcftools` does not have the necessary permissions to read input files or write output files/directories.
*   **Solution:**
    1.  **Script Executability:** Ensure `run_gvcf_pipeline.sh` is executable: `chmod +x run_gvcf_pipeline.sh`.
    2.  **Read Permissions:** Verify you have read access to all input gVCF files.
    3.  **Write Permissions:** Verify you have write access to the current directory (for `standard_chroms.txt`, `gvcf_list.txt`, `filtered_gvcf_list_autosomes.txt`, the final VCF) and to create the `filtered_gvcfs_autosomes/` subdirectory. Use `ls -ld .` to check current directory permissions and `ls -l <filename>` for files.

## 5. Pipeline is Very Slow or Uses Too Much Memory

*   **Cause (Slow):** Processing many large gVCFs is inherently time-consuming. Indexing also takes time.
*   **Cause (Memory):** `bcftools merge` is the most memory-intensive step, especially with hundreds of samples.
*   **Solution:**
    1.  **Patience:** Allow sufficient time for the pipeline to complete.
    2.  **Resources:** Ensure your system has adequate RAM and fast disk I/O if possible.
    3.  **Batching (Advanced):** For extremely large cohorts (many hundreds or thousands of samples), you might need to consider more advanced strategies like merging in batches, which is beyond the scope of this current script.
    4.  Check for other processes consuming system resources.

## 6. Output File is Empty or Missing Expected Variants

*   **Cause A: No Variants on Selected Chromosomes:** Your input samples might not have any variants on `chr1-chr22`.
*   **Cause B: All Variants Filtered by `PASS`:** All variants on the selected chromosomes might have FILTER statuses other than `PASS`.
*   **Cause C: Upstream Filtering:** The `.hard-filtered.gvcf.gz` files might have already been aggressively filtered, leaving few variants.
*   **Cause D: Error in an earlier step:** An error in the `bcftools view` or `bcftools merge` step might have led to an empty intermediate or final file.
*   **Solution:**
    1.  Review the script's output carefully for any warnings or errors during the filtering and merging steps.
    2.  Temporarily remove the `-f PASS` filter in Step 4 of the script to see if variants are present before this filter:
        ```bash
        # Change:
        # ... | bcftools view -f PASS -Oz -o "$FINAL_OUTPUT_VCF"
        # To:
        # ... | bcftools view -Oz -o "$FINAL_OUTPUT_VCF" # No -f PASS
        ```
        Then inspect the output. If variants appear now, the `PASS` filter was removing everything.
    3.  Inspect one of your intermediate filtered files in `filtered_gvcfs_autosomes/` before the merge to see if variants are present after chromosome filtering.

## General Debugging Tips

*   **Run step-by-step:** If the script fails, try running the individual `bcftools` commands (from a problematic step) directly in your terminal on a single file to isolate the issue.
*   **Examine output logs:** Pay close attention to all messages printed by the script and `bcftools`.
*   **Simplify:** Test with a very small subset of your data (e.g., 2-3 gVCFs) to speed up debugging cycles.
*   **Check `bcftools` version:** Ensure you are using a reasonably up-to-date version of `bcftools`. 