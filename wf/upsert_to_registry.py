# This code is part of a workflow for upserting data into a registry table.
from dataclasses import dataclass
import os
from subprocess import run

from latch.ldata.path import LPath

from latch import small_task
from latch.registry.table import Table
from latch.types.file import LatchFile
import logging

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def add_record(tbl: Table, sample: str, output_key: str, value: str, table_id: str, values_upserted: bool) -> LatchFile:
    try:
        with tbl.update() as updater:
            updater.upsert_record(name=sample, **{output_key: value})
    except Exception as e:
        values_upserted = False
        print(f"Error adding record for {output_key} in table {table_id}: {e}")

def add_column(tbl: Table, output_key: str, table_id: int, values_upserted: bool) -> None:
    try:
        with tbl.update() as updater:
            updater.upsert_column(key=output_key, type=str, required=False)
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

@small_task
def parse_json_output(run_flag: bool, outdir: str, table_id: int, sample: str) -> bool:
    import json
    values_upserted = True
    logger.debug(f"Running parse_json_output with run_flag={run_flag}, outdir={outdir}, table_id={table_id}, sample={sample}")
    tbl = Table(id=str(table_id))
    columns = tbl.get_columns()
    logger.debug(f"Columns in table {table_id}: {columns}")
    local_file = pull_json_output(outdir, sample)
    with open(local_file, 'r') as json_file:
        data = json.load(json_file)
    logger.debug(f"Parsed JSON data: {data}")
    for output_key, value in data.items():
        logger.debug(f"{output_key}: {value}")
        if output_key not in columns:
            logger.debug(f"Column {output_key} not found in table {table_id}.")
            add_column(tbl, output_key, table_id, values_upserted)
            add_record(tbl, sample, output_key, value, table_id, values_upserted)
        else:
            logger.debug(f"Column {output_key} found in table {table_id}.")
            add_record(tbl, sample, output_key, value, table_id, values_upserted)

    return values_upserted