#!/bin/bash

################################################################################
# BACKUP MERGE SCRIPT
# 
# Purpose: Complete the merge step if filtering was already done successfully
# Use this if the main pipeline failed during merge but filtering completed
################################################################################

set -euo pipefail

# Configuration
FILTERED_DIR="efficient_output/temp_filtered"  # Adjust if your filtered files are elsewhere
OUTPUT_DIR="filtered_merged_output"
FINAL_VCF="$OUTPUT_DIR/merged_pass_chr1-22.vcf.gz"

echo "========================================="
echo "   BACKUP MERGE SCRIPT"
echo "========================================="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "[INFO] Looking for filtered files in: $FILTERED_DIR"

# Check if filtered files exist
if [ ! -d "$FILTERED_DIR" ]; then
    echo "[ERROR] Filtered directory '$FILTERED_DIR' does not exist"
    echo "[ERROR] Please run the main pipeline first or adjust the FILTERED_DIR path"
    exit 1
fi

# Create clean file list
echo "[INFO] Creating clean file list..."
find "$FILTERED_DIR" -name "*.filtered.vcf.gz" > "$OUTPUT_DIR/clean_filtered_files.txt"

# Check file count
file_count=$(wc -l < "$OUTPUT_DIR/clean_filtered_files.txt")
if [ "$file_count" -eq 0 ]; then
    echo "[ERROR] No filtered files found in '$FILTERED_DIR'"
    exit 1
fi

echo "[SUCCESS] Found $file_count filtered files ready for merging"

# Show sample files
echo "[INFO] Sample files:"
head -5 "$OUTPUT_DIR/clean_filtered_files.txt"
echo ""

echo "[INFO] Starting merge of $file_count files..."

# Run the merge with optimal settings for your hardware
bcftools merge \
    --file-list "$OUTPUT_DIR/clean_filtered_files.txt" \
    --threads 4 \
    -Oz -o "$FINAL_VCF"

# Index the result
echo "[INFO] Indexing merged file..."
bcftools index --threads 4 "$FINAL_VCF"

echo ""
echo "[SUCCESS] Merge completed successfully!"
echo "[SUCCESS] Final output: $FINAL_VCF"

# Show final statistics
echo ""
echo "Final Statistics:"
echo "- File size: $(du -h "$FINAL_VCF" | cut -f1)"
echo "- Total variants: $(bcftools view -H "$FINAL_VCF" | wc -l)"
echo "- Samples: $(bcftools query -l "$FINAL_VCF" | wc -l)"

# Clean up temporary file list
rm -f "$OUTPUT_DIR/clean_filtered_files.txt"

echo ""
echo "========================================="
echo "Your merged VCF is ready for analysis!"
echo "=========================================" 