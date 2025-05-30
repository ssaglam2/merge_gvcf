# Script Explanation (`run_gvcf_pipeline.sh`)

The `run_gvcf_pipeline.sh` script is designed to automate the processing of gVCF files. Here's a breakdown of its key sections and commands:

## Shebang and Initial Echo
```bash
#!/bin/bash
echo "--- Starting gVCF Processing Pipeline (Autosomes chr1-22) ---"
```
* `#!/bin/bash`: Specifies that the script should be executed with BASH.
* The echo command prints a starting message.

## Configuration Variables
```bash
ORIGINAL_GVCF_LIST="gvcf_list.txt"
FILTERED_GVCF_DIR="filtered_gvcfs_autosomes"
# ... and other variables
```
These variables define default names for input lists, output directories, and files. This makes it easier to modify these names in one place if needed.

## Step 0: Create standard_chroms.txt
```bash
echo "[Step 0] Creating $STANDARD_CHROMS_FILE for chr1-chr22..."
seq 1 22 | sed 's/^/chr/' > "$STANDARD_CHROMS_FILE"
# ... verification echos ...
```
This step creates the `standard_chroms.txt` file, which lists the autosomal chromosomes (chr1 to chr22) to be kept.
* `seq 1 22`: Generates numbers from 1 to 22.
* `sed 's/^/chr/'`: Prepends "chr" to each number.
* The output is redirected to `$STANDARD_CHROMS_FILE`.
* Includes checks to display the content and format for verification.

## Step 1: Create gvcf_list.txt
```bash
if [ ! -f "$ORIGINAL_GVCF_LIST" ]; then
    echo "[Step 1] $ORIGINAL_GVCF_LIST not found. Creating it..."
    ls *.hard-filtered.gvcf.gz > "$ORIGINAL_GVCF_LIST" 2>/dev/null
    # ... error checking ...
else
    echo "[Step 1] Using existing $ORIGINAL_GVCF_LIST."
fi
```
* Checks if `$ORIGINAL_GVCF_LIST` (e.g., `gvcf_list.txt`) exists.
* If not, it attempts to create it by listing all files matching `*.hard-filtered.gvcf.gz`.
* Includes error checking to ensure the list is created and populated.

## Step 2: Prepare Directories and Filtered List
```bash
mkdir -p "$FILTERED_GVCF_DIR"
> "$FILTERED_GVCF_LIST"
```
* `mkdir -p`: Creates the directory for intermediate filtered files (e.g., `filtered_gvcfs_autosomes/`) if it doesn't already exist. The `-p` flag prevents errors if the directory exists and creates parent directories if needed.
* `> "$FILTERED_GVCF_LIST"`: Creates an empty file (or truncates an existing one) that will store the paths to the successfully filtered gVCFs.

## Step 3: Filter Individual gVCFs
```bash
while IFS= read -r F_IN; do
    # ... skip empty lines, check if file exists ...
    F_OUT="$FILTERED_GVCF_DIR/$(basename "$F_IN")"
    echo "Processing $F_IN -> $F_OUT"

    bcftools view \
        -t "^$STANDARD_CHROMS_FILE" \
        "$F_IN" \
        -Oz -o "$F_OUT"

    BCFTOOLS_VIEW_EXIT_CODE=$?

    if [ $BCFTOOLS_VIEW_EXIT_CODE -eq 0 ] && [ -s "$F_OUT" ]; then
        bcftools index -t "$F_OUT"
        # ... add to list, count success/failure ...
    fi
done < "$ORIGINAL_GVCF_LIST"
```
This is the main processing loop that iterates through each file listed in `$ORIGINAL_GVCF_LIST`.
* `IFS= read -r F_IN`: Reads each line (filename) safely.
* `basename "$F_IN"`: Extracts the filename from a potential path.
* `bcftools view -t "^$STANDARD_CHROMS_FILE" ...`: This is the crucial filtering step.
  * `-t "^$STANDARD_CHROMS_FILE"`: Tells bcftools to only include regions (chromosomes, in this case) listed in the `$STANDARD_CHROMS_FILE`. The `^` indicates that the argument is a file.
  * `"$F_IN"`: The input gVCF file.
  * `-Oz -o "$F_OUT"`: Outputs a gzipped VCF to the specified output file (`$F_OUT`) in the intermediate directory.
* `BCFTOOLS_VIEW_EXIT_CODE=$?`: Captures the exit status of the bcftools view command.
* The if condition checks if bcftools view was successful (`-eq 0`) and if the output file (`$F_OUT`) is not empty (`-s`).
* If successful, `bcftools index -t "$F_OUT"` indexes the filtered gVCF.
* The path to the successfully filtered and indexed file is appended to `$FILTERED_GVCF_LIST`.
* Counters track successful and failed operations.

## Step 4: Merge Filtered gVCFs and Apply PASS Filter
```bash
if [ "$SUCCESS_COUNT" -eq 0 ]; then
    # ... exit if no files were filtered ...
fi

bcftools merge \
    --gvcf - \
    --file-list "$FILTERED_GVCF_LIST" \
    -Oz \
| \
bcftools view \
    -f PASS \
    -Oz \
    -o "$FINAL_OUTPUT_VCF"
# ... error checking ...
```
* First, it checks if any files were successfully filtered in Step 3.
* `bcftools merge --gvcf - --file-list "$FILTERED_GVCF_LIST" -Oz`:
  * `--gvcf -`: Enables gVCF-aware merging with default settings.
  * `--file-list "$FILTERED_GVCF_LIST"`: Specifies the list of (now chromosome-filtered and indexed) gVCFs to merge.
  * `-Oz`: Outputs a gzipped VCF to standard output, which is then piped.
* `| \ bcftools view -f PASS -Oz -o "$FINAL_OUTPUT_VCF"`:
  * The `|` pipes the output of bcftools merge to bcftools view.
  * `-f PASS`: Filters the merged stream, keeping only records where the FILTER column is PASS.
  * `-Oz -o "$FINAL_OUTPUT_VCF"`: Outputs the final result as a gzipped VCF to `$FINAL_OUTPUT_VCF`.
* Error checking is performed on the pipeline's success and output file creation.

## Step 5: Index the Final Merged File
```bash
bcftools index -t "$FINAL_OUTPUT_VCF"
# ... error checking ...
```
* Indexes the final merged VCF file (`$FINAL_OUTPUT_VCF`) for efficient downstream access.

## Conclusion
```bash
echo "--- Pipeline complete! ---"
# ... final messages ...
```
* Prints completion messages. 