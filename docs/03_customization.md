# Customization Guide

The `run_gvcf_pipeline.sh` script is designed for a common use case but can be customized to fit different requirements.

## 1. Changing Input File Pattern

If your input gVCF files do not follow the `*.hard-filtered.gvcf.gz` pattern, you have two options:

*   **Option A: Manually Create `gvcf_list.txt`**
    Before running the script, create a file named `gvcf_list.txt` in the same directory. List each of your input gVCF filenames, one per line. The script will detect this existing file and use it.

*   **Option B: Modify the Script**
    Open `run_gvcf_pipeline.sh` and find Step 1:
    ```bash
    # Original line:
    ls *.hard-filtered.gvcf.gz > "$ORIGINAL_GVCF_LIST" 2>/dev/null
    ```
    Change `*.hard-filtered.gvcf.gz` to match your file pattern. For example, if your files are just `*.g.vcf.gz`:
    ```bash
    # Modified line:
    ls *.g.vcf.gz > "$ORIGINAL_GVCF_LIST" 2>/dev/null
    ```

## 2. Including Sex Chromosomes or Mitochondrial DNA

The script currently filters for autosomal chromosomes `chr1` through `chr22`. To include sex chromosomes (e.g., `chrX`, `chrY`) or mitochondrial DNA (e.g., `chrM` or `MT`), modify Step 0 where `standard_chroms.txt` is created.

*   **Example: Including `chrX` and `chrY` (assuming "chr" prefix):**
    ```bash
    # Original line in Step 0:
    # seq 1 22 | sed 's/^/chr/' > "$STANDARD_CHROMS_FILE"

    # Modified line to include chrX, chrY:
    { seq 1 22; echo X; echo Y; } | sed 's/^/chr/' > "$STANDARD_CHROMS_FILE"
    ```

*   **Example: Including `chrX`, `chrY`, and `chrM`:**
    ```bash
    # Modified line to include chrX, chrY, chrM:
    { seq 1 22; echo X; echo Y; echo M; } | sed 's/^/chr/' > "$STANDARD_CHROMS_FILE"
    ```

*   **If your chromosomes do NOT use the "chr" prefix (e.g., `1`, `X`, `MT`):**
    You'll need to remove the `| sed 's/^/chr/'` part and adjust the `echo` commands.
    ```bash
    # Example for 1-22, X, Y, MT (no "chr" prefix):
    { seq 1 22; echo X; echo Y; echo MT; } > "$STANDARD_CHROMS_FILE"
    ```
    **Important:** Ensure the names you add to `standard_chroms.txt` exactly match the chromosome names present in your VCF files.

    Also, remember to update the final output filename variable (`FINAL_OUTPUT_VCF`) in the script's configuration section to reflect the new content (e.g., `merged.pass.chrs1-22XY.vcf.gz`).

## 3. Modifying Output Filenames and Directories

The script uses variables at the top for key filenames and directory names:
```bash
ORIGINAL_GVCF_LIST="gvcf_list.txt"
FILTERED_GVCF_DIR="filtered_gvcfs_autosomes"
FILTERED_GVCF_LIST="filtered_gvcf_list_autosomes.txt"
STANDARD_CHROMS_FILE="standard_chroms.txt"
FINAL_OUTPUT_VCF="merged.pass.chrs1-22.vcf.gz"
```
You can change these default values directly in the script if you prefer different naming conventions.

## 4. Changing the PASS Filter

The script filters the final merged VCF for records where the FILTER column is exactly PASS:
```bash
# In Step 4:
# ... | bcftools view -f PASS -Oz -o "$FINAL_OUTPUT_VCF"
```
* `-f PASS`: This part applies the filter.

You can modify this if you need to include other filter statuses (e.g., `.` for unfiltered, or specific warning flags if desired) or apply different filtering logic.

For more complex filtering (e.g., based on INFO fields), you might use `bcftools filter` or the `-i` / `-e` options of `bcftools view`. Refer to the bcftools documentation for advanced filtering expressions. For example, to include both PASS and `.` (unfiltered):
```bash
# Example: include PASS or .
# ... | bcftools view -i 'FILTER="PASS" || FILTER="."' -Oz -o "$FINAL_OUTPUT_VCF"
```

## 5. Adjusting bcftools merge Parameters

The script uses a simple `--gvcf -` for `bcftools merge`. `bcftools merge` has other options that might be relevant for specific gVCF merging scenarios (e.g., related to handling missing data, INFO fields, etc.). Consult the `bcftools merge` documentation if you need to fine-tune this step.

## 6. Running on a Subset of Files

If you don't want to process all `*.hard-filtered.gvcf.gz` files, the easiest way is to:

1. Manually create `gvcf_list.txt`.
2. Add only the filenames of the gVCFs you wish to process into this file, one per line.

The script will use this manually created list. 