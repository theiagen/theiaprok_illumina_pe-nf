#!/usr/bin/env python2
import argparse
import pandas as pd
import sys
from pathlib import Path


"""
Taking old MIDAS python script embedded in WDL

Parse MIDAS species profile output to extract primary and secondary genus information.

This script processes MIDAS species profile TSV files to identify the primary genus
(most abundant) and secondary genus (most abundant non-primary genus with >1% abundance).
"""

def parse_midas_output(input_file, output_dir=None):
    """
    Parse MIDAS species profile output file.
    
    Args:
        input_file (str): Path to the MIDAS species profile TSV file
        output_dir (str, optional): Directory to write output files. Defaults to current directory.
    
    Returns:
        dict: Dictionary containing parsed results
    """
    
    # Set output directory
    if output_dir is None:
        output_dir = Path.cwd()
    else:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
    
    try:
        df = pd.read_csv(input_file, sep="\t", header=0)
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.", file=sys.stderr)
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print(f"Error: Input file '{input_file}' is empty.", file=sys.stderr)
        sys.exit(1)
    
    # Round relative abundance to 4 decimal places
    df = df.round(4)
    
    # Sort by relative abundance (descending)
    sorted_df = df.sort_values(by=['relative_abundance'], ascending=False)
    
    # Split species_id column into genus, species, strain
    sorted_df[['genus', 'species', 'strain']] = sorted_df['species_id'].str.split(
        pat='_', expand=True, n=2
    )
    
    # Capture primary genus (most abundant)
    primary_genus = sorted_df['genus'].iloc[0]
    
    # Filter out rows where genus is the primary genus
    filtered_df = sorted_df[~sorted_df['genus'].str.contains(str(primary_genus), na=False)]
    
    # Re-sort by relative abundance
    filtered_sorted_df = filtered_df.sort_values(by=['relative_abundance'], ascending=False)
    
    # Initialize secondary genus variables
    secondary_genus = "No secondary genus detected (>1% relative abundance)"
    secondary_genus_abundance = 0.0
    secondary_genus_coverage = 0.0
    
    # Check if there are any secondary genera
    if len(filtered_sorted_df) > 0:
        # Capture secondary genus (most abundant non-primary genus)
        secondary_genus_candidate = filtered_sorted_df['genus'].iloc[0]
        secondary_genus_abundance = filtered_sorted_df['relative_abundance'].iloc[0]
        secondary_genus_coverage = filtered_sorted_df['coverage'].iloc[0]
        
        # Only set secondary genus if abundance is >= 1%
        if secondary_genus_abundance >= 0.01:
            secondary_genus = secondary_genus_candidate
    
    # Here is what we want to capture for midas
    results = {
        'primary_genus': str(primary_genus),
        'secondary_genus': str(secondary_genus),
        'secondary_genus_abundance': float(secondary_genus_abundance),
        'secondary_genus_coverage': float(secondary_genus_coverage)
    }
    
    # Prepare output files similar the the values originally captured
    output_files = {
        'PRIMARY_GENUS.txt': results['primary_genus'],
        'SECONDARY_GENUS.txt': results['secondary_genus'],
        'SECONDARY_GENUS_ABUNDANCE.txt': str(results['secondary_genus_abundance']),
        'SECONDARY_GENUS_COVERAGE.txt': str(results['secondary_genus_coverage'])
    }
    
    for filename, content in output_files.items():
        output_path = output_dir / filename
        with open(output_path, 'w') as f:
            f.write(content)
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Parse MIDAS species profile output to extract genus information",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
            Examples:
            %(prog)s sample_species_profile.tsv
            %(prog)s sample_species_profile.tsv --output-dir ./results
            %(prog)s sample_species_profile.tsv --verbose
        """
    )
    
    parser.add_argument(
        'input_file',
        help='Path to the MIDAS species profile TSV file'
    )
    
    parser.add_argument(
        '--output-dir', '-o',
        help='Directory to write output files (default: current directory)',
        default=None
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Print verbose output'
    )
    
    args = parser.parse_args()
    
    results = parse_midas_output(args.input_file, args.output_dir)
    
    # Print results if verbose - if we need to debug or provide detailed output
    if args.verbose:
        print("MIDAS Analysis Results:")
        print(f"Primary genus: {results['primary_genus']}")
        print(f"Secondary genus: {results['secondary_genus']}")
        print(f"Secondary genus abundance: {results['secondary_genus_abundance']}")
        print(f"Secondary genus coverage: {results['secondary_genus_coverage']}")
        
        output_dir = Path(args.output_dir) if args.output_dir else Path.cwd()
        print(f"\nOutput files written to: {output_dir}")
        print("- PRIMARY_GENUS")
        print("- SECONDARY_GENUS")
        print("- SECONDARY_GENUS_ABUNDANCE")
        print("- SECONDARY_GENUS_COVERAGE")


if __name__ == "__main__":
    main()