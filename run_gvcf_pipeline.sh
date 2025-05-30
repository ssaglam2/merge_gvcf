#!/bin/bash

# Script to filter gVCFs for autosomes (chr1-22), merge, and filter for PASS variants

echo "--- Starting gVCF Processing Pipeline (Autosomes chr1-22) ---"

# --- Configuration ---
# Ensure this script is run from the directory containing your gVCF files
# and where gvcf_list.txt will be/is located.

# Name of the file listing original gVCFs
ORIGINAL_GVCF_LIST="gvcf_list.txt"

# Directory for intermediate chromosome-filtered gVCFs
FILTERED_GVCF_DIR="filtered_gvcfs_autosomes"

# File listing the paths to the filtered gVCFs
FILTERED_GVCF_LIST="filtered_gvcf_list_autosomes.txt"

# File listing standard chromosomes to keep
STANDARD_CHROMS_FILE="standard_chroms.txt"

# Final output file name
FINAL_OUTPUT_VCF="merged.pass.chrs1-22.vcf.gz"

# --- Step 0: Create standard_chroms.txt for autosomes ---
echo "[Step 0] Creating $STANDARD_CHROMS_FILE for chr1-chr22..."
seq 1 22 | sed 's/^/chr/' > "$STANDARD_CHROMS_FILE"
echo "Contents of $STANDARD_CHROMS_FILE (first 5 lines):"
head -n 5 "$STANDARD_CHROMS_FILE"
echo "Format check (first 3 lines of $STANDARD_CHROMS_FILE):"
head -n 3 "$STANDARD_CHROMS_FILE" | od -c
echo "---"

# --- Step 1: Create list of original gVCFs ---
# (Assumes files end with .hard-filtered.gvcf.gz)
if [ ! -f "$ORIGINAL_GVCF_LIST" ]; then
    echo "[Step 1] $ORIGINAL_GVCF_LIST not found. Creating it..."
    ls *.hard-filtered.gvcf.gz > "$ORIGINAL_GVCF_LIST" 2>/dev/null # Suppress "No such file or directory" if no files match
    if [ $? -ne 0 ] || [ ! -s "$ORIGINAL_GVCF_LIST" ]; then
        echo "Error: Failed to create or populate $ORIGINAL_GVCF_LIST. Ensure *.hard-filtered.gvcf.gz files exist in the current directory."
        exit 1
    fi
    echo "$ORIGINAL_GVCF_LIST created."
else
    echo "[Step 1] Using existing $ORIGINAL_GVCF_LIST."
fi
echo "---"

# --- Step 2: Prepare directories and lists for filtered files ---
echo "[Step 2] Preparing directory $FILTERED_GVCF_DIR and list $FILTERED_GVCF_LIST..."
mkdir -p "$FILTERED_GVCF_DIR"
> "$FILTERED_GVCF_LIST" # Create an empty file or clear existing
echo "---"

# --- Step 3: Filter individual gVCFs for standard autosomes ---
echo "[Step 3] Filtering individual gVCFs for standard autosomes (chr1-chr22)..."
SUCCESS_COUNT=0
FAILURE_COUNT=0
while IFS= read -r F_IN; do
    # Skip empty lines in the list
    if [ -z "$F_IN" ]; then
        continue
    fi

    if [ ! -f "$F_IN" ]; then
        echo "Warning: File '$F_IN' listed in $ORIGINAL_GVCF_LIST not found. Skipping."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        continue
    fi

    F_OUT="$FILTERED_GVCF_DIR/$(basename "$F_IN")"
    echo "Processing $F_IN -> $F_OUT"

    bcftools view \
        -t "^$STANDARD_CHROMS_FILE" \
        "$F_IN" \
        -Oz -o "$F_OUT"

    BCFTOOLS_VIEW_EXIT_CODE=$? # Capture exit code of bcftools view

    if [ $BCFTOOLS_VIEW_EXIT_CODE -eq 0 ] && [ -s "$F_OUT" ]; then
        bcftools index -t "$F_OUT"
        if [ $? -eq 0 ]; then
            echo "$F_OUT" >> "$FILTERED_GVCF_LIST"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "Error: Failed to index '$F_OUT'. Skipping."
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        fi
    else
        echo "Warning: Output file '$F_OUT' is empty or bcftools view failed (exit code: $BCFTOOLS_VIEW_EXIT_CODE) for '$F_IN'."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
done < "$ORIGINAL_GVCF_LIST"
echo "Finished filtering individual gVCFs. Successful: $SUCCESS_COUNT, Failed/Skipped: $FAILURE_COUNT."
echo "---"

# --- Step 4: Merge filtered gVCFs and apply PASS filter ---
if [ "$SUCCESS_COUNT" -eq 0 ]; then
    echo "Error: No gVCF files were successfully filtered. Cannot proceed to merge."
    exit 1
fi

echo "[Step 4] Merging filtered gVCFs from $FILTERED_GVCF_LIST and applying PASS filter..."
bcftools merge \
    --gvcf - \
    --file-list "$FILTERED_GVCF_LIST" \
    -Oz \
| \
bcftools view \
    -f PASS \
    -Oz \
    -o "$FINAL_OUTPUT_VCF"

BCFTOOLS_MERGE_EXIT_CODE=$? # Capture exit code of the pipe

if [ $BCFTOOLS_MERGE_EXIT_CODE -ne 0 ] || [ ! -s "$FINAL_OUTPUT_VCF" ]; then
     echo "Error: bcftools merge/view pipeline failed (exit code: $BCFTOOLS_MERGE_EXIT_CODE) or produced an empty output file: $FINAL_OUTPUT_VCF."
     exit 1
fi
echo "---"

# --- Step 5: Index the final merged file ---
echo "[Step 5] Indexing final merged file: $FINAL_OUTPUT_VCF..."
bcftools index -t "$FINAL_OUTPUT_VCF"
if [ $? -ne 0 ]; then
    echo "Error: Failed to index the final output file: $FINAL_OUTPUT_VCF."
    exit 1
fi

echo "--- Pipeline complete! ---"
echo "Final output: $FINAL_OUTPUT_VCF"
echo "And its index: $FINAL_OUTPUT_VCF.tbi" 