
from latch.types.metadata import (
    NextflowMetadata,
    LatchAuthor,
    NextflowRuntimeResources, LatchParameter, LatchMetadata
)
from latch.types.directory import LatchDir
from latch.registry.table import Table
from latch.resources.tasks import small_task

from .parameters import generated_parameters

# is the LatchMetadata compatible with the NextflowMetadata?
# do we need to swap to LatchMetadata if we want to have the table id input?

NextflowMetadata(
    display_name='TheiaProk_Illumina_PE',
    author=LatchAuthor(
        name="Theiagen Genomics",
    ),
    parameters=generated_parameters,
    runtime_resources=NextflowRuntimeResources(
        cpus=4,
        memory=8,
        storage_gib=100,
    ),
    log_dir=LatchDir("latch:///theiaprok_pe_log"),
)

