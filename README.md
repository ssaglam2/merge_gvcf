# gVCF Filter and Merge Tool

A bash script for filtering and merging genomic variant call format (gVCF) files, specifically designed to extract PASS variants from chromosomes 1-22 and merge them into a single VCF file.

## Features

- **Efficient Filtering**: Filters gVCF files for PASS variants only
- **Chromosome Selection**: Processes only autosomes (chromosomes 1-22)
- **Batch Processing**: Handles multiple gVCF files automatically
- **Compression**: Outputs bgzipped VCF files with proper indexing
- **Error Handling**: Robust error checking and informative messages

## Prerequisites

- **Linux Environment**: WSL (Windows Subsystem for Linux) or native Linux
- **bcftools**: Install via `sudo apt-get install bcftools`
- **Input Files**: Compressed gVCF files (`.gvcf.gz` or `.vcf.gz`)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/ssaglam2/merge_gvcf.git
   cd gvcf-filter-merge
   ```

2. Make the script executable:
   ```bash
   chmod +x filter_merge.sh
   ```

## Usage

### Directory Structure

Before running the script, organize your files as follows:

```
your-project/
├── filter_merge.sh
├── gvcf/                    # Input directory
│   ├── sample1.gvcf.gz
│   ├── sample2.gvcf.gz
│   └── ...
└── processed_gvcfs/        # Output directory (created automatically)
```

### Running the Script

1. Place your compressed gVCF files in the `gvcf/` directory
2. Execute the script:
   ```bash
   ./filter_merge.sh
   ```

### Output

The script generates:
- **Filtered individual files**: `processed_gvcfs/[sample].filtered.vcf.gz`
- **Final merged file**: `processed_gvcfs/merged.pass.chr1-22.vcf.gz`
- **Index files**: `.csi` index files for all outputs

## Configuration

The script can be customized by modifying these variables at the top:

```bash
INPUT_DIR="gvcf"                                    # Input directory
OUTPUT_DIR="processed_gvcfs"                        # Output directory
FINAL_MERGED_VCF="$OUTPUT_DIR/merged.pass.chr1-22.vcf.gz"  # Final output name
```

### Chromosome Naming Convention

The script supports different chromosome naming conventions. Modify line 55-60:

For `chr1, chr2, ...` format (default):
```bash
REGIONS=$(seq -f "chr%g" 1 22 | paste -sd,)
```

For `1, 2, ...` format:
```bash
REGIONS=$(seq 1 22 | paste -sd,)
```

## Example Workflow

```bash
# 1. Prepare your data
mkdir -p gvcf
cp /path/to/your/*.gvcf.gz gvcf/

# 2. Run the filtering and merging
./filter_merge.sh

# 3. Check the results
ls -la processed_gvcfs/
bcftools stats processed_gvcfs/merged.pass.chr1-22.vcf.gz
```

## Technical Details

### Filtering Criteria
- **FILTER field**: Only variants with `FILTER=="PASS"`
- **Chromosomes**: Only autosomes (chr1-chr22 or 1-22)

### bcftools Commands Used
- `bcftools view`: For filtering variants and regions
- `bcftools merge`: For combining multiple VCF files
- `bcftools index`: For creating index files

## Troubleshooting

### Common Issues

1. **No files found error**:
   - Ensure gVCF files are in the correct directory
   - Check file extensions (`.gvcf.gz` or `.vcf.gz` or g.vcf.gz)

2. **Chromosome naming mismatch**:
   - Check your VCF headers with: `bcftools view -h your_file.gvcf.gz | grep "##contig"`
   - Adjust the `REGIONS` variable accordingly

3. **Permission denied**:
   - Make the script executable: `chmod +x filter_merge.sh`

4. **bcftools not found**:
   - Install bcftools: `sudo apt-get install bcftools`

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit your changes: `git commit -am 'Add feature'`
4. Push to the branch: `git push origin feature-name`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this tool in your research, please cite:

```
gVCF Filter and Merge Tool
https://github.com/ssaglam2/merge_gvcf
```

## Support

For questions, issues, or suggestions:
- Open an issue on GitHub
- Check existing issues for similar problems
- Include example data and error messages when reporting bugs 