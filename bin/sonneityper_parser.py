#!/usr/bin/env python3
import os
import csv
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse Sonneityper output TSV and extract fields.")
    parser.add_argument("--sonnei_tsv", required=True, help="Path to Sonneityper TSV file.")
    args = parser.parse_args()

    tsv_path = args.sonnei_tsv
    output_files = {
        "SPECIES.txt": "species",
        "FINAL_GENOTYPE.txt": "final genotype",
        "GENOTYPE_NAME.txt": "name",
        "CONFIDENCE.txt": "confidence"
    }

    if os.path.exists(tsv_path):
        with open(tsv_path, 'r') as tsv_file:
            tsv_reader = list(csv.DictReader(tsv_file, delimiter="\t"))
            for line in tsv_reader:
                for output_filename, tsv_column in output_files.items():
                    with open(output_filename, 'wt') as out_f:
                        out_f.write(line[tsv_column])
                break  # Only process the first line -- as was done in original wdl
    else:
        print("DEBUG: Skipping parsing, output files will be empty.")