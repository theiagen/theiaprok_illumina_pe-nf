#!/usr/bin/env python3

import csv
import argparse
import os
import sys

def parse_seqsero2_output(tsv_file_path, output_contamination=True):
    """
    Parse SeqSero2 TSV output file and write individual output files
    
    Args:
        tsv_file_path: Path to SeqSero_result.tsv file
        output_contamination: Whether to output contamination file (False for assembly mode)
    """
    
    if not os.path.exists(tsv_file_path):
        print(f"Error: Input file {tsv_file_path} not found")
        sys.exit(1)
    
    try:
        with open(tsv_file_path, 'r') as tsv_file:
            tsv_reader = list(csv.DictReader(tsv_file, delimiter="\t"))
            
            for line in tsv_reader:
                # Predicted Antigenic Profile
                with open("PREDICTED_ANTIGENIC_PROFILE", 'wt') as predicted_antigen_prof:
                    pred_ant_prof = line['Predicted antigenic profile']
                    if not pred_ant_prof:
                        pred_ant_prof = "None"
                    predicted_antigen_prof.write(pred_ant_prof)
                
                # Predicted Serotype
                with open("PREDICTED_SEROTYPE", 'wt') as predicted_sero:
                    pred_sero = line['Predicted serotype']
                    if not pred_sero:
                        pred_sero = "None"
                    predicted_sero.write(pred_sero)
                
                # Contamination -- only for reads, not assembly
                if output_contamination:
                    with open("CONTAMINATION", 'wt') as contamination_detected:
                        cont_detect = line['Potential inter-serotype contamination']
                        if not cont_detect:
                            cont_detect = "None"
                        contamination_detected.write(cont_detect)
                
                # Capture Sample Note 
                with open("NOTE", 'wt') as note_file:
                    note = line['Note']
                    if not note:
                        note = "None"
                    note_file.write(note)
    
    # Just general exception handling for file parsing errors
    except Exception as exc:
        print(f"Error parsing TSV file: {exc}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Parse SeqSero2 output TSV file')
    parser.add_argument('tsv_file', help='Path to SeqSero_result.tsv file')
    parser.add_argument('samplename', help='Sample name')
    parser.add_argument('--mode', choices=['reads', 'assembly'], default='reads',
                       help='Analysis mode: reads (includes contamination) or assembly (no contamination)')
    
    args = parser.parse_args()
    
    # Contamination output is only relevant for reads mode
    output_contamination = (args.mode == 'reads')
    
    parse_seqsero2_output(args.tsv_file, args.samplename, output_contamination)
    

if __name__ == "__main__":
    main()