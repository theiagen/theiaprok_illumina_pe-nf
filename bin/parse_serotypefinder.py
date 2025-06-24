#!/usr/bin/env python3
import csv
import re
import argparse

def parse_serotypefinder(input_file):
    antigens = []
    h_re = re.compile("H[0-9]*")
    o_re = re.compile("O[0-9]*")

    with open(input_file,'r') as tsv_file:
        tsv_reader = csv.DictReader(tsv_file, delimiter="\t")
        for row in tsv_reader:
            if row.get('Serotype') not in antigens:
                antigens.append(row.get('Serotype'))
    print("Antigens: " + str(antigens))

    h_type = "/".join(set("/".join(list(filter(h_re.match, antigens))).split('/')))
    print("H-type: " + h_type)
    o_type = "/".join(set("/".join(list(filter(o_re.match,antigens))).split('/')))
    print("O-type: " + o_type)

    serotype = "{}:{}".format(o_type,h_type)
    if serotype == ":":
        serotype = "NA"
    print("Serotype: " + serotype)

    with open ("STF_SEROTYPE", 'wt') as stf_serotype:
        stf_serotype.write(str(serotype))

def main():
    parser = argparse.ArgumentParser(description='Parse SerotypeFinder')
    parser.add_argument('--input_file', required=True, help='Path to the SerotypeFinder results TSV file')
    
    args = parser.parse_args()
    
    parse_serotypefinder(args.input_file)

if __name__ == '__main__':
    main()