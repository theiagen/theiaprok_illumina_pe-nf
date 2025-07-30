
from latch.types.metadata import (
    NextflowMetadata,
    LatchAuthor,
    NextflowRuntimeResources,
    LatchParameter,
    LatchMetadata,
    Fork,
    ForkBranch,
    Params,
    Section,
    Spoiler,
    Text,
)
from latch.types.directory import LatchDir
from latch.registry.table import Table
from latch.resources.tasks import small_task

from .parameters import generated_parameters

# is the LatchMetadata compatible with the NextflowMetadata?
# do we need to swap to LatchMetadata if we want to have the table id input?

flow = [
    Section(
        "Input Data",
        Params("table_id", "input"),
        Text("Provide sample information via Latch Registry table or samplesheet"),
    ),
    Section(
        "Sample Configuration", 
        Params("samplename", "read1", "read2", "paired_end", "ont_data", "assembly_only"),
        Spoiler(
            "Workflow Options",
            Params("skip_screen", "workflow_series")
        ),
    ),
    Section(
        "Quality Control & Filtering",
        Params("min_reads", "min_basepairs", "min_genome_length", "max_genome_length"),
        Spoiler(
            "Coverage & Quality Thresholds",
            Params("min_coverage", "min_proportion", "genome_length")
        ),
    ),
    Section(
        "Read Processing & Trimming",
        Params("read_processing", "read_qc"),
        Spoiler(
            "Trimming Parameters",
            Params(
                "trim_min_length", 
                "trim_quality_min_score", 
                "trim_window_size",
                "adapters",
                "phix",
                "fastp_args"
            )
        ),
    ),
    Section(
        "Assembly Configuration",
        Fork(
            "assembler",
            "",
            skesa=ForkBranch(
                "SKESA",
                Params("min_contig_length"),
                Spoiler(
                    "Assembly Options",
                    Params(
                        "kmers",
                        "assembler_options", 
                        "cg_pipe_opts",
                        "quast_min_contig_length"
                    )
                )
            ),
            spades=ForkBranch(
                "SPADES",
                Params("min_contig_length"),
                Spoiler(
                    "Assembly Options",
                    Params(
                        "kmers",
                        "assembler_options", 
                        "cg_pipe_opts",
                        "quast_min_contig_length",
                        "spades_type"
                    ),
                )
            ),
            megahit=ForkBranch(
                "MEGAHIT",
                Params("min_contig_length"),
                Spoiler(
                    "Assembly Options",
                    Params(
                        "kmers",
                        "assembler_options", 
                        "cg_pipe_opts",
                        "quast_min_contig_length"
                    )
                )
            ),
        ),
        Spoiler(
            "Pilon Polishing",
            Params(
                "call_pilon",
                "pilon_min_mapping_quality",
                "pilon_min_base_quality", 
                "pilon_min_depth",
                "pilon_fix"
            )
        ),
    ),
    Section(
        "Contig Filtering",
        Params("run_filter_contigs"),
        Spoiler(
            "Filtering Parameters",
            Params(
                "filter_contigs_min_length",
                "filter_contigs_min_coverage",
                "filter_contigs_skip_length_filter",
                "filter_contigs_skip_coverage_filter", 
                "filter_contigs_skip_homopolymer_filter"
            )
        ),
    ),
    Section(
        "Genome Characterization",
        Params("perform_characterization"),
        Spoiler(
            "Analysis Tools",
            Params(
                "call_ani",
                "call_kmerfinder", 
                "call_resfinder",
                "call_plasmidfinder",
                "call_abricate",
                "call_midas",
                "call_kraken",
                "call_stxtyper",
                "call_poppunk", 
                "run_amr_search",
                "run_merlin_magic"
            )
        ),
    ),
    Section(
        "Genome Annotation",
        Params("genome_annotation", "bakta_db", "expected_taxon"),
    ),
    Section(
        "Database Paths",
        Spoiler(
            "Analysis Databases",
            Params(
                "midas_db",
                "kraken_db", 
                "kmerfinder_db",
                "gambit_db_genomes",
                "gambit_db_signatures",
                "bakta_db_path"
            )
        ),
        Spoiler(
            "Resistance & Plasmid Databases", 
            Params(
                "resfinder_db_res",
                "resfinder_db_point",
                "plasmidfinder_db",
                "plasmidfinder_db_path",
                "plasmidfinder_method_path"
            )
        ),
    ),
    Section(
        "Output Configuration",
        Params("outdir"),
        Spoiler(
            "System Options",
            Params("publish_dir_mode", "email", "email_on_fail")
        ),
    ),
    Spoiler(
        "Advanced Analysis Parameters",
        Spoiler(
            "AMR Analysis",
            Params(
                "abricate_db",
                "amrfinder_min_percent_identity",
                "amrfinder_min_percent_coverage",
                "amrfinder_detailed_drug_class",
                "amrfinder_hide_point_mutations",
                "amrfinder_separate_betalactam_genes"
            )
        ),
        Spoiler(
            "ResFinder Options",
            Params(
                "resfinder_organism",
                "resfinder_acquired", 
                "resfinder_min_percent_coverage",
                "resfinder_min_percent_identity",
                "resfinder_call_pointfinder"
            )
        ),
        Spoiler(
            "PlasmidFinder Options", 
            Params(
                "plasmidfinder_min_percent_coverage",
                "plasmidfinder_min_percent_identity"
            )
        ),
        Spoiler(
            "Typing & Characterization",
            Params(
                "mlst_nopath",
                "mlst_scheme",
                "mlst_min_percent_identity", 
                "mlst_min_percent_coverage",
                "mlst_minscore"
            )
        ),
        Spoiler(
            "Virulence Analysis",
            Params(
                "virulencefinder_database",
                "virulencefinder_min_percent_coverage",
                "virulencefinder_min_percent_identity"
            )
        ),
        Spoiler(
            "Tuberculosis Analysis",
            Params(
                "tbp_parser_config",
                "tbp_parser_sequencing_method",
                "tbp_parser_operator",
                "tbp_parser_min_depth",
                "tbp_parser_min_frequency",
                "tbp_parser_debug"
            )
        ),
        Spoiler(
            "Population Genomics",
            Params(
                "poppunk_gps_db_url",
                "poppunk_gps_external_clusters_url"
            )
        ),
    ),
]

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
    flow=flow,
)

