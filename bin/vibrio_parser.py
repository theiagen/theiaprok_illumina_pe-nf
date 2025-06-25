#!/usr/bin/env python3
import csv
import re
import argparse
import os
import sys

"""
Converting from wdl embedded script to a standalone python script
"""

def tsv_to_dict(filename) -> dict:
    """Convert TSV file into list of dictionaries"""
    result_list = []
    with open(filename) as file_obj:
        reader = csv.DictReader(file_obj, delimiter='\t')
        for row in reader:
            result_list.append(dict(row))
    # only one sample is run, so there's only one row, flattening list
    return result_list[0]

def translate_chars(string) -> str:
    """Make characters human-readable"""
    translation = []
    if '?' in string:
        translation.append("low depth/uncertain")
    if '-' in string:
        translation.append("not detected")
    
    # in case we want to retrieve the allele information
    string = re.sub(r"\*|\?|-", "", string)

    if len(translation) > 0:
        return '(' + ';'.join(translation) + ')'
    return ""

def parse_srst2_vibrio_output(tsv_file_path):
    """
    Parse SRST2 Vibrio TSV output file and write individual output files
    
    Args:
        tsv_file_path: Path to the SRST2 output TSV file
    """
    
    if not os.path.exists(tsv_file_path):
        print(f"Error: Input file {tsv_file_path} not found")
        sys.exit(1)
    
    try:
        # Converting None to empty string
        conv = lambda i : i or '-'
        
        # load output TSV as dict 
        row = tsv_to_dict(tsv_file_path)
      
        # presence or absence genes - ctxA, ompW and toxR
        with open("ctxA", "w") as ctxA_fh:
            value = row.get("ctxA")
            presence = translate_chars(conv(value))
            if presence == "(not detected)":
                ctxA_fh.write(presence)
            else:
                result = "present" + ' ' + presence
                ctxA_fh.write(result.strip())
        
        with open("ompW", "w") as ompW_fh:
            value = row.get("ompW")
            presence = translate_chars(conv(value))
            if presence == "(not detected)":
                ompW_fh.write(presence)
            else:
                result = "present" + ' ' + presence
                ompW_fh.write(result.strip())
        
        with open("toxR", "w") as toxR_fh:
            value = row.get("toxR")
            presence = translate_chars(conv(value))
            if presence == "(not detected)":
                toxR_fh.write(presence)
            else:
                result = "present" + ' ' + presence
                toxR_fh.write(result.strip())
        
        # biotype - tcpA classical or tcpA ElTor
        with open("BIOTYPE", "w") as biotype_fh:
            value_ElTor = translate_chars(conv(row.get("tcpA_ElTor")))
            value_classical = translate_chars(conv(row.get("tcpA_classical")))

            if value_ElTor == "(not detected)" and value_classical == "(not detected)":
                biotype_fh.write("(not detected)")
            else:
                if value_ElTor == "(not detected)":
                    result = "tcpA_Classical" + ' ' + value_classical
                    biotype_fh.write(result.strip())
                else:
                    result = "tcpA_ElTor" + ' ' + value_ElTor
                    biotype_fh.write(result.strip())
                
        # serogroup - O1 or O139
        with open("SEROGROUP", "w") as serotype_fh:
            value_O1 = translate_chars(conv(row.get("wbeN_O1")))
            value_O139 = translate_chars(conv(row.get("wbfR_O139")))

            if value_O1 == "(not detected)" and value_O139 == "(not detected)":
                serotype_fh.write("(not detected)")
            else:
                if value_O1 == "(not detected)":
                    result = "O139" + ' ' + value_O139
                    serotype_fh.write(result.strip())
                else:
                    result = "O1" + ' ' + value_O1
                    serotype_fh.write(result.strip())
    
    except Exception as exc:
        print(f"Error parsing TSV file: {exc}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Parse SRST2 Vibrio output TSV file')
    parser.add_argument('tsv_file', help='Path to SRST2 output TSV file')
    
    args = parser.parse_args()
    
    parse_srst2_vibrio_output(args.tsv_file, args.prefix)

if __name__ == "__main__":
    main()