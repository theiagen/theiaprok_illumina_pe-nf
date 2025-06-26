#!/usr/bin/env python3
import csv
import argparse

def parse_tbprofiler(input):
    with open(input,'r') as tsv_file:
        tsv_reader=csv.reader(tsv_file, delimiter="\t")
        tsv_data=list(tsv_reader)
        tsv_dict=dict(zip(tsv_data[0], tsv_data[1]))

        with open ("MAIN_LINEAGE", 'wt') as main_lineage:
            main_lineage.write(tsv_dict['main_lineage'])
        with open ("SUB_LINEAGE", 'wt') as sublineage:
            sublineage.write(tsv_dict['sub_lineage'])
        
        with open ("DR_TYPE", 'wt') as dr_type:
            dr_type.write(tsv_dict['drtype'])
        with open ("NUM_DR_VARIANTS", 'wt') as num_dr_variants:
            num_dr_variants.write(tsv_dict['num_dr_variants'])
        with open ("NUM_OTHER_VARIANTS", 'wt') as num_other_variants:
            num_other_variants.write(tsv_dict['num_other_variants'])

        with open ("RESISTANCE_GENES", 'wt') as resistance_genes:
            res_genes_list=['rifampicin', 'isoniazid', 'ethambutol', 'pyrazinamide', 'moxifloxacin', 'levofloxacin', 'bedaquiline', 'delamanid', 'pretomanid', 'linezolid', 'streptomycin', 'amikacin', 'kanamycin', 'capreomycin', 'clofazimine', 'ethionamide', 'para-aminosalicylic_acid', 'cycloserine']
            res_genes=[]
            for i in res_genes_list:
                if tsv_dict[i] != '-':
                    res_genes.append(tsv_dict[i])
            res_genes_string=';'.join(res_genes)
            resistance_genes.write(res_genes_string)

        with open ("MEDIAN_DEPTH", 'wt') as median_depth:
            median_depth.write(tsv_dict['target_median_depth'])
        with open ("PCT_READS_MAPPED", 'wt') as pct_reads_mapped:
            pct_reads_mapped.write(tsv_dict['pct_reads_mapped'])

def main():
    parser = argparse.ArgumentParser(description='Parse TBProfiler')
    parser.add_argument('--input_file', required=True, help='Path to the TBProfiler results TXT file')
    
    args = parser.parse_args()
    
    parse_tbprofiler(args.input_file)