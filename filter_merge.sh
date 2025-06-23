#!/bin/bash

# ==============================================================================
# SCRIPT: filter_and_merge_gvcfs.sh
# DESCRIPTION: A script to first filter multiple gVCF files for PASS variants
#              on chromosomes 1-22, and then merge the results.
#
# PREREQUISITES:
#   - WSL (Windows Subsystem for Linux)
#   - bcftools (installed via `sudo apt-get install bcftools`)
#
# USAGE:
#   1. Place this script in your project directory.
#   2. Create a subdirectory named 'raw_gvcfs' and place all your input
#      gVCF files (e.g., sampleA.g.vcf.gz) inside it.
#   3. Run from the terminal: ./filter_and_merge_gvcfs.sh
# ==============================================================================

# --- Script Configuration ---

# Exit immediately if a command exits with a non-zero status.
set -e

# Directory containing your raw gVCF files (must end in .g.vcf.gz or .vcf.gz)
INPUT_DIR="gvcf"

# Directory to store intermediate and final results. This will be created if it doesn't exist.
OUTPUT_DIR="processed_gvcfs"

# Filename for the final, merged VCF
FINAL_MERGED_VCF="$OUTPUT_DIR/merged.pass.chr1-22.vcf.gz"

# --- Main Script Logic ---

echo "--- gVCF Filtering and Merging Pipeline Started ---"

# 1. Setup: Create output directory
mkdir -p "$OUTPUT_DIR"
echo "[INFO] Input directory:  '$INPUT_DIR'"
echo "[INFO] Output directory: '$OUTPUT_DIR'"

# This file will hold the list of filtered gVCFs to be merged.
# We create it fresh each time the script runs.
FILE_LIST="$OUTPUT_DIR/files_to_merge.txt"
> "$FILE_LIST"

# 2. Filter each gVCF for PASS variants and chromosomes 1-22
echo ""
echo "--- Step 1: Filtering individual gVCFs for PASS and chr1-22 ---"

# Generate the regions string for chromosomes 1-22.
# IMPORTANT: Check your VCF header for chromosome naming convention.
#
# USE THIS LINE for chromosome names like 'chr1', 'chr2', etc.
REGIONS=$(seq -f "chr%g" 1 22 | paste -sd,)
#
# OR, USE THIS LINE for names like '1', '2', etc.
# REGIONS=$(seq 1 22 | paste -sd,)

echo "[INFO] Filtering for regions: $REGIONS"

# Check if there are any gVCF files to process
shopt -s nullglob
files=("$INPUT_DIR"/*.gvcf.gz "$INPUT_DIR"/*.vcf.gz)   # g.vcf.gz or gvcf.gz setting
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    echo "[ERROR] No *.g.vcf.gz or *.vcf.gz files found in the '$INPUT_DIR' directory."
    echo "Please place your compressed gVCF files there and try again."
    exit 1
fi

for gvcf_file in "${files[@]}"
do
    # Get the base name of the file
    base_name=$(basename "$gvcf_file" .g.vcf.gz | xargs basename -s .vcf.gz)
    
    # Define the output filename for the filtered gVCF
    filtered_gvcf="$OUTPUT_DIR/${base_name}.filtered.vcf.gz"
    
    echo "Processing: $gvcf_file -> $filtered_gvcf"
    
    # Use a single bcftools command to apply both filters for efficiency
    # -Oz: Output compressed VCF (bgzipped) which is required for indexing
    # --include 'FILTER=="PASS"': The PASS filter expression
    # --regions "$REGIONS" : The chromosome filter
    bcftools view \
        --include 'FILTER=="PASS"' \
        --regions "$REGIONS" \
        -Oz -o "$filtered_gvcf" "$gvcf_file"
    
    # Index the newly created filtered file. This is required for merging.
    bcftools index "$filtered_gvcf"
    
    # Add the path of the new file to our list for merging
    echo "$filtered_gvcf" >> "$FILE_LIST"
done

echo "[SUCCESS] All individual gVCFs have been filtered and indexed."

# 3. Merge all filtered VCFs
echo ""
echo "--- Step 2: Merging all filtered files ---"

num_files=$(wc -l < "$FILE_LIST")
echo "Merging $num_files files listed in $FILE_LIST..."

# Use bcftools merge with the --file-list option
# -Oz: Output a compressed VCF
bcftools merge \
    --file-list "$FILE_LIST" \
    -Oz -o "$FINAL_MERGED_VCF"

# Optional: Create an index for the final merged file
bcftools index "$FINAL_MERGED_VCF"

echo ""
echo "--- Pipeline Finished! ---"
echo "Final, merged VCF is located at: $FINAL_MERGED_VCF"
echo "Intermediate files (e.g., *.filtered.vcf.gz) are in '$OUTPUT_DIR' and can be removed if no longer needed."
echo "--------------------------"
