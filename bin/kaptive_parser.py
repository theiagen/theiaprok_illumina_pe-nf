#!/usr/bin/env python3
import argparse
import csv
import sys
from pathlib import Path

"""
Kaptive Output Parser - Converting this from the original script to a more structured Python script 
and to reduce redundancy.

https://github.com/theiagen/public_health_bioinformatics/blob/main/tasks/species_typing/acinetobacter/task_kaptive.wdl

This script parses Kaptive output TSV files and extracts key information
into separate files. Supports both K locus and OC locus modes.

Usage:
    python kaptive_parser.py --mode k --input sample_kaptive_out_k_table.txt
    python kaptive_parser.py --mode oc --input sample_kaptive_out_oc_table.txt
"""

def parse_kaptive_output(input_file: Path, mode: str) -> None:
    """
    Parse Kaptive output file and create individual output files for each field.
    
    Args:
        input_file: Path to the Kaptive output TSV file
        mode: Either 'k' or 'oc' to specify the locus type
        
    Raises:
        FileNotFoundError: If input file doesn't exist
        ValueError: If mode is not 'k' or 'oc'
    """
    if mode not in ['k', 'oc']:
        raise ValueError("Mode must be either 'k' or 'oc'")
    
    if not input_file.exists():
        raise FileNotFoundError(f"Input file not found: {input_file}")
    
    try:
        with open(input_file, 'r') as tsv_file:
            tsv_reader = csv.reader(tsv_file, delimiter="\t")
            tsv_data = list(tsv_reader)
            
            if len(tsv_data) < 2:
                raise ValueError("Input file must have at least 2 rows (header + data)")
            
            tsv_dict = dict(zip(tsv_data[0], tsv_data[1]))
    except Exception as exc:
        print(f"Error reading input file: {exc}", file=sys.stderr)
        sys.exit(1)
    
    # K or OC mode suffix
    mode_suffix = mode.upper()
    
    output_mappings = {
        f'BEST_MATCH_LOCUS_{mode_suffix}': 'Best match locus',
        f'BEST_MATCH_TYPE_{mode_suffix}': 'Best match type',
        f'MATCH_CONFIDENCE_{mode_suffix}': 'Match confidence',
        f'NUM_EXPECTED_INSIDE_{mode_suffix}': 'Expected genes in locus',
        f'EXPECTED_GENES_IN_LOCUS_{mode_suffix}': 'Expected genes in locus, details',
        f'NUM_EXPECTED_OUTSIDE_{mode_suffix}': 'Expected genes outside locus',
        f'EXPECTED_GENES_OUT_LOCUS_{mode_suffix}': 'Expected genes outside locus, details',
        f'NUM_OTHER_INSIDE_{mode_suffix}': 'Other genes in locus',
        f'OTHER_GENES_IN_LOCUS_{mode_suffix}': 'Other genes in locus, details',
        f'NUM_OTHER_OUTSIDE_{mode_suffix}': 'Other genes outside locus',
        f'OTHER_GENES_OUT_LOCUS_{mode_suffix}': 'Expected genes outside locus, details' # This was repeated twice in original code
    }
    
    created_files = []
    for output_filename, tsv_column in output_mappings.items():
        try:
            value = tsv_dict.get(tsv_column, '')
            with open(output_filename, 'w') as output_file:
                output_file.write(value)
            created_files.append(output_filename)
            print(f"Created: {output_filename}")
        except Exception as e:
            print(f"Error creating {output_filename}: {e}", file=sys.stderr)
    
    print(f"\nsuccessfully created {len(created_files)} output files for {mode.upper()} locus analysis")


def main() -> None:
    """Main function to handle command line arguments and execute parsing."""
    parser = argparse.ArgumentParser(
        description="Parse Kaptive output files and extract key information",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
        Examples:
        python kaptive_parser.py --mode k --input sample_kaptive_out_k_table.txt
        python kaptive_parser.py --mode oc --input sample_kaptive_out_oc_table.txt
        """
    )
    
    parser.add_argument(
        '--mode', '-m',
        choices=['k', 'oc'],
        required=True,
        help='Analysis mode: k for K locus, oc for OC locus'
    )
    
    parser.add_argument(
        '--input', '-i',
        type=Path,
        required=True,
        help='Path to the Kaptive output TSV file'
    )
    
    parser.add_argument(
        '--version', '-v',
        action='version',
        version='%(prog)s 1.0'
    )
    
    args = parser.parse_args()
    
    try:
        parse_kaptive_output(args.input, args.mode)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()