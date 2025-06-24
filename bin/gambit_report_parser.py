#!/usr/bin/env python3
import json
import csv
import re
import argparse
import os
import sys
from typing import Dict, List, Any, Optional, Union


def fmt_dist(d: float) -> str:
    """Format distance value to 4 decimal places."""
    return format(d, '.4f')


def write_output(file: str, search_item: Optional[Dict[str, Any]], column: str, empty_value: Union[str, float]) -> None:
    """
    Output-writing function to reduce redundancy for gambit values.
    
    Args:
        file: Output filename
        search_item: Dictionary item to search
        column: Column/key name to extract
        empty_value: Value to write if item/column is None
    """
    with open(file, 'w') as f:
        if search_item is None:
            f.write(empty_value)
        elif search_item[column] is None:
            f.write(empty_value)
        else:
            if str(empty_value) == str(fmt_dist(0)):
                f.write(fmt_dist(search_item[column]))
            else:
                # remove candidate sub-speciation from taxon name
                if column == 'name':
                    gambit_name = search_item[column]
                    # Remove _X where X is any letter, GTDB does this novel naming thing
                    gambit_name = re.sub(r'_[A-Za-z]+', '', gambit_name) 
                    f.write(gambit_name)
                else:
                    f.write(search_item[column])


def generate_merlin_tag(predicted_taxon: Optional[Dict[str, Any]]) -> str:
    """
    Generate merlin tag for organism-specific workflows.
    
    Args:
        predicted_taxon: Predicted taxon dictionary
        
    Returns:
        str: Merlin tag designation
    """
    merlin_tag_designations = {
        "Escherichia": "Escherichia", 
        "Shigella": "Escherichia", 
        "Shigella sonnei": "Shigella sonnei",
        "Klebsiella": "Klebsiella", 
        "Klebsiella pneumoniae": "Klebsiella pneumoniae", 
        "Klebsiella oxytoca": "Klebsiella oxytoca", 
        "Klebsiella aerogenes": "Klebsiella aerogenes", 
        "Listeria": "Listeria", 
        "Salmonella": "Salmonella", 
        "Vibrio": "Vibrio",
        "Vibrio cholerae": "Vibrio cholerae"
    }

    try:
        merlin_tag: str = predicted_taxon['name']
        # remove candidate sub-speciation from merlin_tag
        merlin_tag = re.sub(r'_[A-Za-z]+', '', merlin_tag)
    except (KeyError, TypeError):
        merlin_tag = "NA"

    # see if there is a reduced tag available (use Escherichia for Shigella flexneri)
    reduced_name: List[str] = [val for key, val in merlin_tag_designations.items() if key in merlin_tag]

    if len(reduced_name) > 0:  # if a reduced tag was identified, check if it should be used
        if (reduced_name[0] in merlin_tag_designations.keys()) and (merlin_tag not in merlin_tag_designations.keys()):
            merlin_tag = reduced_name[0]

    return merlin_tag


def parse_gambit_report(json_file: str, sample_name: str, output_dir: str = ".") -> None:
    """
    Parse GAMBIT JSON report and generate output files.
    
    Args:
        json_file: Path to GAMBIT JSON report file
        sample_name: Sample name for output file naming
        output_dir: Directory for output files (default: current directory)
    """
    
    closest_genomes_path = os.path.join(output_dir, f"{sample_name}_gambit_closest.csv")
    
    try:
        with open(json_file) as f:
            data: Dict[str, Any] = json.load(f)
    except FileNotFoundError:
        print(f"Error: Could not find file {json_file}")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON format in {json_file}")
        sys.exit(1)

    # Extract main data elements
    try:
        (item,) = data['items']
        predicted: Optional[Dict[str, Any]] = item['predicted_taxon']
        next_taxon: Optional[Dict[str, Any]] = item['next_taxon']
        closest: Dict[str, Any] = item['closest_genomes'][0]
    except (KeyError, IndexError, ValueError) as e:
        print(f"Error: Invalid GAMBIT report structure - {e}")
        sys.exit(1)

    # Write closest distance
    with open(os.path.join(output_dir, 'CLOSEST_DISTANCE'), 'w') as f:
        f.write(fmt_dist(closest['distance']))

    # Write predicted taxon information
    write_output(os.path.join(output_dir, 'PREDICTED_TAXON'), predicted, 'name', 'NA')
    write_output(os.path.join(output_dir, 'PREDICTED_TAXON_RANK'), predicted, 'rank', 'NA')
    write_output(os.path.join(output_dir, 'PREDICTED_TAXON_THRESHOLD'), predicted, 'distance_threshold', fmt_dist(0))

    # Write next taxon information
    write_output(os.path.join(output_dir, 'NEXT_TAXON'), next_taxon, 'name', 'NA')
    write_output(os.path.join(output_dir, 'NEXT_TAXON_RANK'), next_taxon, 'rank', 'NA')
    write_output(os.path.join(output_dir, 'NEXT_TAXON_THRESHOLD'), next_taxon, 'distance_threshold', fmt_dist(0))

    # Generate table of closest genomes
    with open(closest_genomes_path, 'w', newline='') as f:
        writer = csv.writer(f)

        writer.writerow([
            'distance',
            'genome.description',
            'genome.taxon.name',
            'genome.taxon.rank',
            'genome.taxon.threshold',
            'matched.name',
            'matched.rank',
            'matched.distance_threshold',
        ])

        for match in item['closest_genomes']:
            genome: Dict[str, Any] = match['genome']
            genome_taxon: Dict[str, Any] = genome['taxonomy'][0]
            match_taxon: Optional[Dict[str, Any]] = match['matched_taxon']

            writer.writerow([
                fmt_dist(match['distance']),
                genome['description'],
                genome_taxon['name'],
                genome_taxon['rank'],
                fmt_dist(genome_taxon['distance_threshold']),
                '' if match_taxon is None else match_taxon['name'],
                '' if match_taxon is None else match_taxon['rank'],
                fmt_dist(0 if match_taxon is None else match_taxon['distance_threshold']),
            ])

    # Generate and write merlin tag
    merlin_tag: str = generate_merlin_tag(predicted)
    print(f"Merlin tag: {merlin_tag}")
    
    with open(os.path.join(output_dir, 'MERLIN_TAG'), 'w') as merlin:
        merlin.write(merlin_tag)

    print(f"Successfully processed GAMBIT report for sample: {sample_name}")
    print(f"Output files written to: {output_dir}")


def main() -> None:
    """Main function with command line argument parsing."""
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Parse GAMBIT JSON report and generate output files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
            Examples:
            python gambit_report_parser.py sample1_gambit.json sample1
            python gambit_report_parser.py report.json sample1 --output-dir /path/to/output
        """
    )
    
    parser.add_argument(
        'gambit_report',
        help='Path to GAMBIT JSON report file'
    )
    
    parser.add_argument(
        'sample_name',
        help='Sample name for output file naming'
    )
    
    parser.add_argument(
        '--output-dir', '-o',
        default='.',
        help='Output directory for generated files (default: current directory)'
    )
    
    args: argparse.Namespace = parser.parse_args()
    
    # Create output directory if it doesn't exist
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)
    
    # Parse the GAMBIT report
    parse_gambit_report(args.gambit_report, args.sample_name, args.output_dir)


if __name__ == "__main__":
    main()