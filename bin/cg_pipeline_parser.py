#!/usr/bin/env python3
import csv
import argparse

def parse_cg_pipeline_output(prefix, read1, metrics, concat_metrics):
    coverage = 0.0
    with open(metrics,'r') as tsv_file:
      tsv_reader = list(csv.DictReader(tsv_file, delimiter="\t"))
      for line in tsv_reader:
        if read1 in line["File"]:
          with open("R1_MEAN_Q.txt", 'wt') as r1_mean_q:
            r1_mean_q.write(line["avgQuality"])
          with open("R1_MEAN_LENGTH.txt", 'wt') as r1_mean_length:
            r1_mean_length.write(line["avgReadLength"])

          # run_assembly_readMetrics can report coverage as '.'
          try:
            coverage = float(line["coverage"])
          except ValueError:
            continue
          print(coverage)
          
        else:
          with open("R2_MEAN_Q.txt", 'wt') as r2_mean_q:
            r2_mean_q.write(line["avgQuality"])
          with open("R2_MEAN_LENGTH.txt", 'wt') as r2_mean_length:
            r2_mean_length.write(line["avgReadLength"])
          # run_assembly_readMetrics can report coverage as '.'
          try:
            coverage += float(line["coverage"])
          except ValueError:
            continue

      with open("EST_COVERAGE.txt", 'wt') as est_coverage:
        est_coverage.write("{:.6f}".format(coverage))

    # parse concatenated read metrics
    # grab output average quality and coverage scores by column header
    with open(concat_metrics,'r') as tsv_file_concat:
      tsv_reader_concat = list(csv.DictReader(tsv_file_concat, delimiter="\t"))
      for line in tsv_reader_concat:
        if prefix + "_concat" in line["File"]:
          with open("COMBINED_MEAN_Q.txt", 'wt') as combined_mean_q:
            combined_mean_q.write(line["avgQuality"])
          with open("COMBINED_MEAN_LENGTH.txt", 'wt') as combined_mean_length:
            combined_mean_length.write(line["avgReadLength"])

def main():
    parser = argparse.ArgumentParser(description='Parse CG pipeline output')
    parser.add_argument('--prefix', required=True, help='Prefix for the output files')
    parser.add_argument('--read1', required=True, help='Read 1 name pattern')
    parser.add_argument('--metrics', required=True, help='Path to the read metrics TSV file')
    parser.add_argument('--concat_metrics', required=True, help='Path to the concatenated read metrics TSV file')
    
    args = parser.parse_args()
    
    parse_cg_pipeline_output(args.prefix, args.read1, args.metrics, args.concat_metrics)

if __name__ == '__main__':
    main()

