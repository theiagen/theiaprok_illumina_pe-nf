# This code is part of a workflow for upserting data into a registry table.
from dataclasses import dataclass
from subprocess import run
import json
from typing import List, Dict, Any
from latch.ldata.path import LPath
from pathlib import Path
from latch.account import Account
from latch import small_task
from latch.registry.table import Table
from latch.types import LatchFile
import typing
import logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def add_record(tbl: Table, sample: str, output_key: str, value: str, table_id: str, values_upserted: bool) -> LatchFile:
    try:
        logger.debug(f"Adding record for {sample}; {output_key} in table {table_id} with value: {value}")
        with tbl.update() as updater:
            updater.upsert_record(name=sample, **{output_key: value})
    except Exception as e:
        values_upserted = False
        print(f"Error adding record for {output_key} in table {table_id}: {e}")

def add_column(tbl: Table, output_key: str, table_id: int, values_upserted: bool, type: str) -> None:
    try:
        
        print(f"Adding column {output_key} to table {table_id} with type {type}")
        with tbl.update() as updater:
            if type == "List[LatchFile]":
                updater.upsert_column(key=output_key, type=List[LatchFile], required=False)
            else:
                updater.upsert_column(key=output_key, type=type, required=False)
        print(f"Column {output_key} added to table {table_id}.")
    except Exception as e:
        values_upserted = False
        print(f"Error adding column {output_key} to table {table_id}: {e}")

def pull_json_output(outdir: str, sample: str) -> LatchFile:
    logger.debug(f"Pulling JSON output for sample {sample} from directory {outdir}")
    logger.debug(f"Building file path for sample {sample}")
    filename = f"{sample}.json"
    json_directory = "/utility_json_builder/"
    outdir += "/"
    path = f"{outdir}{sample}{json_directory}{filename}"
    logger.debug(f"Full path to JSON file: {path}")
    latch_path = LPath(path)
    local_file = LatchFile(latch_path.path).local_path
    logger.debug(f"Local file path: {local_file}")

    return local_file

def record_sample_array(tbl: Table) -> list[str]:
    sample_array = []
    for page in tbl.list_records():
        for record_id, record in page.items():
            values = record.get_values()
            sample_name = values["sample"]
            sample_array.append(sample_name)
    logger.debug(f"Sample array: {sample_array}")
    return sample_array

def collect_file_locations(collated_file: dict, latch_acc_address: str):
    published_files = {}
    for task in collated_file['tasks']:
        for output_name, output_data in task['outputs'].items():
            sample_name = task['tag']
            #logger.debug(f"Processing task for sample: {sample_name}")
            #logger.debug(f"Processing output: {output_name}")
            if 'value_results' not in output_name:
                #logger.debug(f"Output {output_name} does not contain 'value_results'")
                if 'publishedFiles' in output_data:
                    #logger.debug(f"Adding published files for output {output_name}: {output_data['publishedFiles']}")
                    latch_list = []
                    for file in output_data['publishedFiles']:
                        latch_list.append(LatchFile(f"{latch_acc_address}/{file}"))
                        #logger.debug(f"Added LatchFile: {latch_list}")
                    if output_name not in published_files:
                        published_files[output_name] = [(sample_name, latch_list)]
                    else:
                        published_files[output_name].append((sample_name, latch_list))      
    #logger.debug(f"Collected published files: {published_files}")
    return published_files

def parse_json_output(run_flag: bool, outdir: str, table_id: int, sample: str) -> bool:
    values_upserted = True
    logger.debug(f"Running parse_json_output with run_flag={run_flag}, outdir={outdir}, table_id={table_id}, sample={sample}")

    tbl = Table(id=str(table_id))
    columns = tbl.get_columns()

    logger.debug(f"Columns in table {table_id}: {columns}")
    local_file = pull_json_output(outdir, sample)

    with open(local_file, 'r') as json_file:
        data = json.load(json_file)
    logger.debug(f"Parsed JSON data: {data}")

    # upserting other values
    for output_key, value in data.items():
        logger.debug(f"{output_key}: {value}")
        if output_key not in columns:
            add_column(tbl, output_key, table_id, values_upserted, type=str)
            add_record(tbl, sample, output_key, value, table_id, values_upserted)
        else:
            logger.debug(f"Column {output_key} found in table {table_id}.")
            add_record(tbl, sample, output_key, value, table_id, values_upserted)

    return values_upserted