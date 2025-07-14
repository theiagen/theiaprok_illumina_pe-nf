import os
from pathlib import Path

from latch.registry.table import Table
from latch.resources.tasks import small_task
from latch.types.file import LatchFile 

@small_task
def registry_task(record_name: str, file: LatchFile) -> LatchFile:
    file_path = Path(file.local_path)
    file_size = os.stat(file_path).st_size

    tbl = Table(id="1234")
    with tbl.update() as updater:
        updater.upsert_record(
            name=record_name,
            File=file,
            Size=file_size
        )

    return file

def return_records(table_id: int):
    tbl = Table(id=table_id)
    records = tbl.list_records()
    for page in records:
        for record in page:
            print(record)
    