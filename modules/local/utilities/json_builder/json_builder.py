#!/usr/bin/env python3
import glob
import json
import argparse
import os
import logging

def make_json(value_files, prefix):
    # Create a dictionary to store filename: content pairs
    result_data = {}
    
    # Process each file in the array
    logging.info(f"Input file paths: {value_files}")
    for file in value_files.split(' '):
        logging.info(f"Processing file path: {file}")
        file = file.strip()
        if file:
            # Extract just the filename without extension
            file_basename = os.path.basename(file)  # Gets just the filename with extension
            file_name = os.path.splitext(file_basename)[0].lower()  # Removes the extension and sets to lower case
            logging.info(f"Processing file: {file} with key: {file_name}")
            try:
                with open(file, 'r') as f:
                    logging.info(f"Reading content from {file}")
                    content = f.read().strip()
                    result_data[file_name] = content
                    logging.info(f"Successfully read content from {file}")
            except Exception as e:
                logging.error(f"Error reading file {file}: {e}")

    # Write to JSON file
    with open(f"{prefix}.json", "w") as outfile:
        logging.info(f"Writing results to {prefix}.json")
        json.dump(result_data, outfile, indent=2)

def main():

    # Set up logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    parser = argparse.ArgumentParser(description='Generate JSON summaries')
    parser.add_argument('--value_files', required=True, help='List of file paths to read')
    parser.add_argument('--prefix', required=True, help='Prefix for the output JSON file')
    
    args = parser.parse_args()
    
    make_json(args.value_files, args.prefix)

if __name__ == '__main__':
    main()