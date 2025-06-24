#!/usr/bin/env python3
import csv
import argparse
import os
import sys

"""
Moving things over from wdl python for kleborate to stand alone script
"""

def parse_kleborate_output(tsv_file_path):
    """
    Parse Kleborate TSV output file and write individual output files
    
    Args:
        tsv_file_path: Path to the kleborate output TSV file
    """
    
    if not os.path.exists(tsv_file_path):
        print(f"Error: Input file {tsv_file_path} not found")
        sys.exit(1)
    
    try:
        with open(tsv_file_path, 'r') as tsv_file:
            tsv_reader = csv.reader(tsv_file, delimiter="\t")
            tsv_data = list(tsv_reader)
            
            if len(tsv_data) < 2:
                print("Error: TSV file does not contain enough data")
                sys.exit(1)
                
            tsv_dict = dict(zip(tsv_data[0], tsv_data[1]))
            
            with open("SPECIES", 'wt') as species_file:
                kleb_species = tsv_dict.get('species', '')
                species_file.write(kleb_species)
            
            with open("MLST_SEQUENCE_TYPE", 'wt') as mlst_file:
                mlst = tsv_dict.get('ST', '')
                mlst_file.write(mlst)
            
            with open("VIRULENCE_SCORE", 'wt') as virulence_file:
                virulence_level = tsv_dict.get('virulence_score', '')
                virulence_file.write(virulence_level)
            
            with open("RESISTANCE_SCORE", 'wt') as resistance_file:
                resistance_level = tsv_dict.get('resistance_score', '')
                resistance_file.write(resistance_level)
            
            with open("NUM_RESISTANCE_GENES", 'wt') as num_resistance_file:
                resistance_genes_count = tsv_dict.get('num_resistance_genes', '')
                num_resistance_file.write(resistance_genes_count)
            
            with open("BLA_RESISTANCE_GENES", 'wt') as bla_resistance_file:
                bla_res_genes_list = ['Bla_acquired', 'Bla_inhR_acquired', 'Bla_ESBL_acquired', 
                                     'Bla_ESBL_inhR_acquired', 'Bla_Carb_acquired']
                bla_res_genes = []
                for gene in bla_res_genes_list:
                    if tsv_dict.get(gene, '-') != '-':
                        bla_res_genes.append(tsv_dict[gene])
                bla_res_genes_string = ';'.join(bla_res_genes)
                bla_resistance_file.write(bla_res_genes_string)
            
            # ESBL Resistance Genes
            with open("ESBL_RESISTANCE_GENES", 'wt') as esbl_resistance_file:
                esbl_res_genes_list = ['Bla_ESBL_acquired', 'Bla_ESBL_inhR_acquired']
                esbl_res_genes = []
                for gene in esbl_res_genes_list:
                    if tsv_dict.get(gene, '-') != '-':
                        esbl_res_genes.append(tsv_dict[gene])
                esbl_res_genes_string = ';'.join(esbl_res_genes)
                esbl_resistance_file.write(esbl_res_genes_string)
            
            # Key Resistance Genes
            with open("KEY_RESISTANCE_GENES", 'wt') as key_resistance_file:
                key_res_genes_list = ['Col_acquired', 'Fcyn_acquired', 'Flq_acquired', 'Rif_acquired', 
                                     'Bla_acquired', 'Bla_inhR_acquired', 'Bla_ESBL_acquired', 
                                     'Bla_ESBL_inhR_acquired', 'Bla_Carb_acquired']
                key_res_genes = []
                for gene in key_res_genes_list:
                    if tsv_dict.get(gene, '-') != '-':
                        key_res_genes.append(tsv_dict[gene])
                key_res_genes_string = ';'.join(key_res_genes)
                key_resistance_file.write(key_res_genes_string)
            
            # Genomic Resistance Mutations
            with open("GENOMIC_RESISTANCE_MUTATIONS", 'wt') as resistance_mutations_file:
                res_mutations_list = ['Bla_chr', 'SHV_mutations', 'Omp_mutations', 'Col_mutations', 'Flq_mutations']
                res_mutations = []
                for mutation in res_mutations_list:
                    if tsv_dict.get(mutation, '-') != '-':
                        res_mutations.append(tsv_dict[mutation])
                res_mutations_string = ';'.join(res_mutations)
                resistance_mutations_file.write(res_mutations_string)
            
            # K Type
            with open("K_TYPE", 'wt') as ktype_file:
                ktype = tsv_dict.get('K_type', '')
                ktype_file.write(ktype)
            
            # K Locus
            with open("K_LOCUS", 'wt') as klocus_file:
                klocus = tsv_dict.get('K_locus', '')
                klocus_file.write(klocus)
            
            # O Type
            with open("O_TYPE", 'wt') as otype_file:
                otype = tsv_dict.get('O_type', '')
                otype_file.write(otype)
            
            # O Locus
            with open("O_LOCUS", 'wt') as olocus_file:
                olocus = tsv_dict.get('O_locus', '')
                olocus_file.write(olocus)
            
            # K Locus Confidence
            with open("K_LOCUS_CONFIDENCE", 'wt') as k_locus_confidence_file:
                k_locus_confidence = tsv_dict.get('K_locus_confidence', '')
                k_locus_confidence_file.write(k_locus_confidence)
            
            # O Locus Confidence
            with open("O_LOCUS_CONFIDENCE", 'wt') as o_locus_confidence_file:
                o_locus_confidence = tsv_dict.get('O_locus_confidence', '')
                o_locus_confidence_file.write(o_locus_confidence)
    
    except Exception as exc:
        print(f"Error parsing TSV file: {exc}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Parse Kleborate output TSV file')
    parser.add_argument('tsv_file', help='Path to Kleborate output TSV file')
    
    args = parser.parse_args()
    
    parse_kleborate_output(args.tsv_file)

if __name__ == "__main__":
    main()