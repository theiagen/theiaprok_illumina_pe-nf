#!/usr/bin/env python2
import argparse
import pandas as pd
import sys
import os

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
        output_dir = os.getcwd()
    else:
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
    
    try:
        df = pd.read_csv(input_file, sep="\t", header=0)
    except IOError:
        print >> sys.stderr, "Error: Input file '{}' not found.".format(input_file)
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print >> sys.stderr, "Error: Input file '{}' is empty.".format(input_file)
        sys.exit(1)
    
    # Round relative abundance to 4 decimal places
    df = df.round(4)
    
    # Sort by relative abundance (descending)
    sorted_df = df.sort_values(by=['relative_abundance'], ascending=False)
    
    # Split species_id column into genus, species, strain
    split_cols = sorted_df['species_id'].str.split(pat='_', expand=True, n=2)
    sorted_df['genus'] = split_cols.iloc[:, 0] if len(split_cols.columns) > 0 else ''
    sorted_df['species'] = split_cols.iloc[:, 1] if len(split_cols.columns) > 1 else ''
    sorted_df['strain'] = split_cols.iloc[:, 2] if len(split_cols.columns) > 2 else ''
    
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
        output_path = os.path.join(output_dir, filename)
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
    
    args = parser.parse_args()
    
    results = parse_midas_output(args.input_file, args.output_dir)
    

if __name__ == "__main__":
    main()