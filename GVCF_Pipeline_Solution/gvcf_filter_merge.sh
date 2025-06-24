#!/bin/bash

################################################################################
# GVCF FILTER & MERGE PIPELINE
# 
# Purpose: Filter GVCF files for PASS variants and chromosomes 1-22, then merge
# Author: Optimized for Intel Xeon E-2124 + 16GB RAM + WSL
# Version: 1.0
#
# This script performs:
# 1. Dependency validation
# 2. Input file validation and chromosome naming detection
# 3. Parallel filtering of GVCF files (PASS variants, chr1-22 only)
# 4. Efficient merging of filtered files
# 5. Proper indexing and cleanup
################################################################################

set -euo pipefail

################################################################################
#                             CONFIGURATION                                    #
################################################################################

# Input directory containing GVCF files (.gvcf.gz or .g.vcf.gz)
INPUT_DIR="gvcf"

# Output directory for all results
OUTPUT_DIR="filtered_merged_output"

# Final merged VCF filename
FINAL_VCF="$OUTPUT_DIR/merged_pass_chr1-22.vcf.gz"

# Chromosomes to include (auto-detected, but you can modify if needed)
CHROMOSOMES="chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22"

# Performance settings optimized for Intel Xeon E-2124 (4-core) + 16GB RAM
# Rationale:
# - E-2124 has 4 cores without hyperthreading
# - 2 parallel jobs × 2 threads = 4 total threads (matches CPU cores exactly)
# - Conservative approach prevents memory exhaustion with large GVCF files
# - Leaves RAM headroom for bcftools operations (~8GB per job)
MAX_PARALLEL_JOBS=2
THREADS_PER_JOB=2

# Temporary directory for intermediate files
TEMP_DIR="$OUTPUT_DIR/temp_filtered"

################################################################################
#                              FUNCTIONS                                       #
################################################################################

# Print colored messages for better user experience
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Check if required dependencies are installed
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v bcftools &> /dev/null; then
        missing_deps+=("bcftools")
    fi
    
    if ! command -v tabix &> /dev/null; then
        missing_deps+=("tabix")
    fi
    
    if ! command -v parallel &> /dev/null; then
        print_warning "GNU parallel not found. Installing it will significantly speed up processing."
        print_info "Install with: sudo apt update && sudo apt install parallel"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Install with: sudo apt update && sudo apt install ${missing_deps[*]}"
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Validate input files and detect chromosome naming convention
validate_input_files() {
    print_info "Validating input files..."
    
    if [ ! -d "$INPUT_DIR" ]; then
        print_error "Input directory '$INPUT_DIR' does not exist"
        exit 1
    fi
    
    # Count GVCF files
    local gvcf_count=$(find "$INPUT_DIR" -name "*.gvcf.gz" -o -name "*.g.vcf.gz" | wc -l)
    
    if [ "$gvcf_count" -eq 0 ]; then
        print_error "No GVCF files found in '$INPUT_DIR'"
        print_error "Expected files with extensions: .gvcf.gz or .g.vcf.gz"
        exit 1
    fi
    
    print_success "Found $gvcf_count GVCF files to process"
    
    # Auto-detect chromosome naming convention
    local sample_file=$(find "$INPUT_DIR" -name "*.gvcf.gz" -o -name "*.g.vcf.gz" | head -1)
    print_info "Checking chromosome naming convention using: $(basename "$sample_file")"
    
    local has_chr_prefix=$(bcftools view -h "$sample_file" | grep -c "##contig=<ID=chr" || true)
    local has_numeric=$(bcftools view -h "$sample_file" | grep -c "##contig=<ID=[0-9]" || true)
    
    if [ "$has_chr_prefix" -gt 0 ]; then
        print_info "Detected 'chr' prefix in chromosome names (e.g., chr1, chr2)"
    elif [ "$has_numeric" -gt 0 ]; then
        print_warning "Detected numeric chromosome names (e.g., 1, 2)"
        print_warning "Updating chromosome list to use numeric format"
        CHROMOSOMES="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22"
    else
        print_warning "Could not determine chromosome naming convention"
        print_warning "Using default 'chr' prefix. Adjust CHROMOSOMES variable if needed."
    fi
    
    print_info "Will filter for chromosomes: $CHROMOSOMES"
}

# Filter a single GVCF file (used by parallel processing)
filter_single_gvcf() {
    local input_file="$1"
    local base_name=$(basename "$input_file" .gvcf.gz)
    base_name=$(basename "$base_name" .g.vcf.gz)
    
    local output_file="$TEMP_DIR/${base_name}.filtered.vcf.gz"
    
    # Filter for PASS variants and specified chromosomes
    bcftools view \
        --include 'FILTER="PASS"' \
        --regions "$CHROMOSOMES" \
        --threads "$THREADS_PER_JOB" \
        -Oz -o "$output_file" \
        "$input_file" 2>/dev/null
    
    # Index the filtered file (required for merging)
    bcftools index --threads "$THREADS_PER_JOB" "$output_file" 2>/dev/null
    
    echo "$output_file"
}

# Export function and variables for parallel processing
export -f filter_single_gvcf
export TEMP_DIR CHROMOSOMES THREADS_PER_JOB

# Filter all GVCF files using parallel processing
filter_all_gvcfs() {
    print_info "Filtering GVCF files for PASS variants and chromosomes 1-22..."
    
    # Create list of input files
    local file_list="$OUTPUT_DIR/input_files.txt"
    find "$INPUT_DIR" -name "*.gvcf.gz" -o -name "*.g.vcf.gz" > "$file_list"
    
    # Use parallel processing if available, otherwise sequential
    if command -v parallel &> /dev/null; then
        print_info "Using GNU parallel for faster processing ($MAX_PARALLEL_JOBS jobs)"
        parallel -j "$MAX_PARALLEL_JOBS" --bar filter_single_gvcf {} :::: "$file_list" > /dev/null
    else
        print_info "Processing files sequentially (install GNU parallel for faster processing)"
        while IFS= read -r file; do
            filter_single_gvcf "$file" > /dev/null
        done < "$file_list"
    fi
    
    # Create clean list of filtered files for merging
    local filtered_list="$OUTPUT_DIR/filtered_files.txt"
    find "$TEMP_DIR" -name "*.filtered.vcf.gz" > "$filtered_list"
    
    local filtered_count=$(wc -l < "$filtered_list")
    print_success "Successfully filtered $filtered_count files"
    
    echo "$filtered_list"
}

# Merge all filtered VCF files into final output
merge_filtered_vcfs() {
    local file_list="$1"
    
    print_info "Merging filtered VCF files..."
    
    local total_files=$(wc -l < "$file_list")
    print_info "Merging $total_files files into: $FINAL_VCF"
    
    # Use bcftools merge with optimal threading
    bcftools merge \
        --file-list "$file_list" \
        --threads $((MAX_PARALLEL_JOBS * THREADS_PER_JOB)) \
        -Oz -o "$FINAL_VCF"
    
    # Index the final merged file
    print_info "Indexing final merged VCF..."
    bcftools index --threads $((MAX_PARALLEL_JOBS * THREADS_PER_JOB)) "$FINAL_VCF"
    
    print_success "Merged VCF created: $FINAL_VCF"
}

# Clean up temporary files to save disk space
cleanup_temp_files() {
    print_info "Cleaning up temporary files..."
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Remove temporary file lists
    rm -f "$OUTPUT_DIR/input_files.txt"
    rm -f "$OUTPUT_DIR/filtered_files.txt"
    
    print_success "Cleanup completed"
}

# Generate summary statistics about the processing
generate_summary() {
    print_info "Generating summary statistics..."
    
    local summary_file="$OUTPUT_DIR/pipeline_summary.txt"
    
    {
        echo "GVCF Processing Pipeline Summary"
        echo "==============================="
        echo "Date: $(date)"
        echo "Input directory: $INPUT_DIR"
        echo "Output directory: $OUTPUT_DIR"
        echo "Final merged VCF: $FINAL_VCF"
        echo "Chromosomes included: $CHROMOSOMES"
        echo ""
        echo "Processing Configuration:"
        echo "- Parallel jobs: $MAX_PARALLEL_JOBS"
        echo "- Threads per job: $THREADS_PER_JOB"
        echo "- Total CPU threads used: $((MAX_PARALLEL_JOBS * THREADS_PER_JOB))"
        echo ""
        echo "File Statistics:"
        echo "- Input files processed: $(find "$INPUT_DIR" -name "*.gvcf.gz" -o -name "*.g.vcf.gz" | wc -l)"
        echo "- Final VCF size: $(du -h "$FINAL_VCF" | cut -f1)"
        echo "- Total variants: $(bcftools view -H "$FINAL_VCF" | wc -l)"
        echo "- Samples in final VCF: $(bcftools query -l "$FINAL_VCF" | wc -l)"
        echo ""
        echo "Quality Control:"
        echo "- All variants have FILTER=PASS"
        echo "- Only autosomes (chromosomes 1-22) included"
        echo "- All files properly indexed"
        echo ""
        echo "Output Files:"
        echo "- Main result: $FINAL_VCF"
        echo "- Index file: ${FINAL_VCF}.tbi"
        echo "- This summary: $summary_file"
    } > "$summary_file"
    
    print_success "Summary saved to: $summary_file"
    cat "$summary_file"
}

################################################################################
#                              MAIN EXECUTION                                  #
################################################################################

main() {
    echo "================================="
    echo "   GVCF FILTER & MERGE PIPELINE"
    echo "================================="
    echo ""
    
    # Create output directories
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Step 1: Validate environment and inputs
    check_dependencies
    validate_input_files
    
    echo ""
    print_info "Starting pipeline with configuration:"
    print_info "- Input directory: $INPUT_DIR"
    print_info "- Output directory: $OUTPUT_DIR"
    print_info "- Parallel jobs: $MAX_PARALLEL_JOBS"
    print_info "- Threads per job: $THREADS_PER_JOB"
    print_info "- Target chromosomes: $CHROMOSOMES"
    echo ""
    
    # Step 2: Filter all GVCF files
    local filtered_files_list
    filtered_files_list=$(filter_all_gvcfs)
    
    echo ""
    
    # Step 3: Merge filtered files
    merge_filtered_vcfs "$filtered_files_list"
    
    echo ""
    
    # Step 4: Clean up temporary files
    cleanup_temp_files
    
    echo ""
    
    # Step 5: Generate summary
    generate_summary
    
    echo ""
    print_success "Pipeline completed successfully!"
    print_success "Final output: $FINAL_VCF"
    print_info "You can now use this file for downstream analysis (PLINK, VEP, etc.)"
}

# Run the main function with all arguments passed to script
main "$@" 