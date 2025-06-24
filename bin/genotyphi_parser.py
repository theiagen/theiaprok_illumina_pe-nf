#!/usr/bin/env python3

import csv
import argparse
import os
import sys

def parse_genotyphi_output(tsv_file_path):
    """
    Parse Genotyphi TSV output file and write individual output files
    
    Args:
        tsv_file_path: Path to the genotyphi predictResults.tsv file
    """
    
    if not os.path.exists(tsv_file_path):
        print(f"Error: Input file {tsv_file_path} not found")
        sys.exit(1)
    
    try:
        with open(tsv_file_path, 'r') as tsv_file:
            tsv_reader = list(csv.DictReader(tsv_file, delimiter="\t"))
            
            for line in tsv_reader:
                # Species
                with open("SPECIES", 'wt') as genotyphi_species:
                    species = line.get("species", "")
                    genotyphi_species.write(species)
                
                # Species percent coverage
                with open("SPP_PERCENT", 'wt') as species_percent:
                    spp_percent = line.get("spp_percent", "")
                    species_percent.write(spp_percent)
                
                # Final genotype
                with open("FINAL_GENOTYPE", 'wt') as final_genotype:
                    genotype = line.get("final genotype", "")
                    final_genotype.write(genotype)
                
                # Confidence
                with open("CONFIDENCE", 'wt') as genotyphi_confidence:
                    confidence = line.get("confidence", "")
                    genotyphi_confidence.write(confidence)
                    
                # Only process the first line since there should be only one sample
                # That's how it's done in the wdl task
                break
    
    except Exception as exc:
        print(f"Error parsing TSV file: {exc}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Parse Genotyphi output TSV file')
    parser.add_argument('tsv_file', help='Path to genotyphi predictResults.tsv file')
    
    args = parser.parse_args()
    
    parse_genotyphi_output(args.tsv_file)

if __name__ == "__main__":
    main()