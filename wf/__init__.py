from dataclasses import dataclass
from enum import Enum
from pathlib import Path
import typing_extensions
import typing
import json
from typing import List, Dict, Any, Optional
from latch import workflow, small_task
from latch.registry.table import Table
from latch.account import Account
from latch.types.directory import LatchDir, LatchOutputDir
from latch.types import metadata
from flytekit.core.annotation import FlyteAnnotation
from latch.resources.workflow import workflow
from latch.types import metadata
from latch.types.directory import LatchDir, LatchOutputDir

import wf.upsert_to_registry as outputs_to_registry
from wf.entrypoint import initialize, nextflow_runtime, Sample 
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@small_task
def process_results(run_flag: bool, input_samples: typing.List[Sample], outdir: LatchDir, table_id: int, collated_data: str) -> str:
    """Process results and upsert to registry for all samples."""
    print(f"Processing dictionary: {collated_data}")
    for sample in input_samples:
        outputs_to_registry.parse_json_output(
            run_flag=run_flag, 
            outdir=str(outdir.remote_path), 
            table_id=table_id, 
            sample=sample.sample
        )
    # upserting files        
    tbl = Table(id=str(table_id))
    columns = tbl.get_columns()
    acc = Account.current()
    logger.debug(f"Current account ID: {acc.id}")
    latch_acc_address = f"latch://{acc.id}.account"
    logger.debug(f"Latch Account Address: {latch_acc_address}")
    collated_data = json.loads(collated_data)
    parsed_collate = outputs_to_registry.collect_file_locations(collated_data, latch_acc_address)
    logger.debug(f"Parsed collated data: {parsed_collate}")

    for output_key, value in parsed_collate.items():
        if output_key not in columns:
            outputs_to_registry.add_column(tbl, output_key, table_id, True, type="List[LatchFile]")
            for elm in value:
                outputs_to_registry.add_record(tbl, elm[0], output_key, elm[1], table_id, True)
        else:
            logger.debug(f"Column {output_key} found in table {table_id}.")
            for elm in value:
                logger.debug(f"Adding record for {elm[0]} with value {elm[1]} to column {output_key} in table {table_id}.")
                outputs_to_registry.add_record(tbl, elm[0], output_key, elm[1], table_id, True)
    return "Results processed for all samples"
    
@workflow(metadata._nextflow_metadata)
def nf_theiaprok_illumina_pe(
    table_id: int,
    input: typing.List[Sample],
    outdir: typing_extensions.Annotated[LatchDir, FlyteAnnotation({'output': True})],
    samplename: typing.Optional[str],
    read1: typing.Optional[str],
    read2: typing.Optional[str],
    ont_data: typing.Optional[bool],
    assembly_only: typing.Optional[bool],
    genome_length: typing.Optional[str],
    adapters: typing.Optional[str],
    phix: typing.Optional[str],
    kmers: typing.Optional[str],
    assembler_options: typing.Optional[str],
    cg_pipe_opts: typing.Optional[str],
    call_pilon: typing.Optional[bool],
    filter_contigs_skip_length_filter: typing.Optional[bool],
    filter_contigs_skip_coverage_filter: typing.Optional[bool],
    filter_contigs_skip_homopolymer_filter: typing.Optional[bool],
    call_ani: typing.Optional[bool],
    call_kmerfinder: typing.Optional[bool],
    call_resfinder: typing.Optional[bool],
    call_abricate: typing.Optional[bool],
    call_midas: typing.Optional[bool],
    call_stxtyper: typing.Optional[bool],
    call_poppunk: typing.Optional[bool],
    run_amr_search: typing.Optional[bool],
    expected_taxon: typing.Optional[str],
    resfinder_db_res: typing.Optional[str],
    resfinder_db_point: typing.Optional[str],
    plasmidfinder_db: typing.Optional[str],
    plasmidfinder_db_path: typing.Optional[str],
    plasmidfinder_method_path: typing.Optional[str],
    vibecheck_vibrio_barcodes: typing.Optional[str],
    amrfinder_detailed_drug_class: typing.Optional[bool],
    amrfinder_hide_point_mutations: typing.Optional[bool],
    amrfinder_separate_betalactam_genes: typing.Optional[bool],
    resfinder_organism: typing.Optional[str],
    resfinder_acquired: typing.Optional[bool],
    resfinder_call_pointfinder: typing.Optional[bool],
    mlst_nopath: typing.Optional[bool],
    mlst_scheme: typing.Optional[str],
    stxtyper_enable_debugging: typing.Optional[bool],
    ectyper_verify: typing.Optional[bool],
    ectyper_print_alleles: typing.Optional[bool],
    spatyper_do_enrich: typing.Optional[bool],
    tbp_parser_config: typing.Optional[str],
    tbp_parser_sequencing_method: typing.Optional[str],
    tbp_parser_operator: typing.Optional[str],
    tbp_parser_coverage_regions_bed: typing.Optional[str],
    tbp_parser_add_cycloserine_lims: typing.Optional[bool],
    tbp_parser_tngs: typing.Optional[bool],
    tbp_parser_expert_rule_regions_bed: typing.Optional[str],
    email: typing.Optional[str],
    email_on_fail: typing.Optional[str],
    plaintext_email: typing.Optional[bool],
    monochrome_logs: typing.Optional[bool],
    hook_url: typing.Optional[str],
    help_full: typing.Optional[bool],
    show_hidden: typing.Optional[bool],
    version: typing.Optional[bool],
    trace_report_suffix: typing.Optional[str],
    skip_screen: bool = False,
    paired_end: bool = True,
    workflow_series: str = 'theiaprok',
    min_reads: int = 7472,
    min_basepairs: int = 2241820,
    min_genome_length: int = 100000,
    max_genome_length: int = 18040666,
    min_coverage: int = 10,
    min_proportion: int = 40,
    trim_min_length: int = 50,
    trim_quality_min_score: int = 20,
    trim_window_size: int = 4,
    read_processing: str = 'trimmomatic',
    read_qc: str = 'fastqc',
    fastp_args: str = '--detect_adapter_for_pe -g -5 20 -3 20',
    assembler: typing.Optional[str] = 'skesa',
    min_contig_length: int = 200,
    quast_min_contig_length: int = 500,
    spades_type: str = 'isolate',
    pilon_min_mapping_quality: int = 60,
    pilon_min_base_quality: int = 3,
    pilon_min_depth: float = 0.25,
    pilon_fix: str = 'bases',
    run_filter_contigs: bool = True,
    filter_contigs_min_length: int = 200,
    filter_contigs_min_coverage: int = 2,
    perform_characterization: bool = True,
    call_plasmidfinder: bool = True,
    call_kraken: bool = True,
    run_merlin_magic: bool = True,
    genome_annotation: str = 'prokka',
    bakta_db: str = 'full',
    midas_db: str = 'latch://tgn-latch-dev-database-2025.mount/midas/midas_db_v1.2.tar.gz',
    kraken_db: str = 'latch://tgn-latch-dev-database-2025.mount/kraken2/terra_databases_kraken2_kraken2.kalamari_5.1.tar',
    kmerfinder_db: str = 'latch://tgn-latch-dev-database-2025.mount/kmerfinder/kmerfinder_bacteria_20230911.tar.gz',
    gambit_db_genomes: str = 'latch://tgn-latch-dev-database-2025.mount/gambit/gambit-metadata-2.0.1-20250505.gdb',
    gambit_db_signatures: str = 'latch://tgn-latch-dev-database-2025.mount/gambit/gambit-signatures-2.0.1-20250505.gs',
    bakta_db_path: str = 'latch://tgn-latch-dev-database-2025.mount/bakta/',
    abricate_db: str = 'vfdb',
    amrfinder_min_percent_identity: float = 0.9,
    amrfinder_min_percent_coverage: float = 0.5,
    resfinder_min_percent_coverage: float = 0.5,
    resfinder_min_percent_identity: float = 0.9,
    plasmidfinder_min_percent_coverage: float = 0.6,
    plasmidfinder_min_percent_identity: float = 0.9,
    mlst_min_percent_identity: int = 95,
    mlst_min_percent_coverage: int = 10,
    mlst_minscore: int = 50,
    kaptive_start_end_margin: int = 10,
    kaptive_min_percent_coverage: int = 90,
    kaptive_min_percent_identity: int = 80,
    kaptive_low_gene_percent_identity: int = 95,
    abricate_abaum_min_percent_identity: int = 80,
    abricate_abaum_min_percent_coverage: int = 80,
    lissero_min_percent_identity: int = 95,
    lissero_min_percent_coverage: int = 95,
    ectyper_o_min_percent_identity: int = 90,
    ectyper_h_min_percent_identity: int = 95,
    ectyper_o_min_percent_coverage: int = 90,
    ectyper_h_min_percent_coverage: int = 50,
    pbptyper_database: str = '[]',
    pbptyper_min_percent_identity: int = 95,
    pbptyper_min_percent_coverage: int = 95,
    emmtyper_wf: str = 'blast',
    emmtyper_cluster_distance: int = 500,
    emmtyper_min_percent_identity: int = 95,
    emmtyper_culling_limit: int = 5,
    emmtyper_mismatch: int = 4,
    emmtyper_align_diff: int = 5,
    emmtyper_gap: int = 2,
    emmtyper_min_perfect: int = 15,
    emmtyper_min_good: int = 15,
    emmtyper_max_size: int = 2000,
    hicap_min_gene_percent_coverage: float = 0.8,
    hicap_min_gene_depth: float = 0.7,
    hicap_min_gene_length: int = 60,
    hicap_min_gene_percent_identity: float = 0.8,
    srst2_min_percent_coverage: int = 90,
    srst2_max_divergence: int = 10,
    srst2_min_depth: int = 5,
    srst2_min_edge_depth: int = 2,
    srst2_gene_max_mismatch: int = 10,
    abricate_vibrio_min_percent_identity: int = 80,
    abricate_vibrio_min_percent_coverage: int = 80,
    virulencefinder_database: str = 'virulence_ecoli',
    virulencefinder_min_percent_coverage: float = 0.6,
    virulencefinder_min_percent_identity: float = 0.9,
    tbp_parser_min_depth: int = 10,
    tbp_parser_min_frequency: float = 0.1,
    tbp_parser_min_read_support: int = 10,
    tbp_parser_min_percent_coverage: int = 100,
    tbp_parser_debug: bool = True,
    tbp_parser_rrs_frequncy: float = 0.1,
    tbp_parser_rrs_read_support: int = 10,
    tbp_parser_rr1_frequency: float = 0.1,
    tbp_parser_rr1_read_support: int = 10,
    tbp_parser_rpob499_frequency: float = 0.1,
    tbp_parser_etha237_frequency: float = 0.1,
    poppunk_gps_db_url: str = 'https://gps-project.cog.sanger.ac.uk/GPS_6.tar.gz',
    poppunk_gps_external_clusters_url: str = 'https://gps-project.cog.sanger.ac.uk/GPS_v6_external_clusters.csv',
    publish_dir_mode: str = 'copy',
    pipelines_testdata_base_path: str = 'https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/',
    validate_params: bool = True,
) -> None:
    """
    TheiaProk_Illumina_PE

    Sample Description
    """
    pvc_name: str = initialize()
    run_flag, collated_data = nextflow_runtime(table_id=table_id, pvc_name=pvc_name, input=input, outdir=outdir, samplename=samplename, read1=read1, read2=read2, paired_end=paired_end, ont_data=ont_data, assembly_only=assembly_only, skip_screen=skip_screen, workflow_series=workflow_series, min_reads=min_reads, min_basepairs=min_basepairs, min_genome_length=min_genome_length, max_genome_length=max_genome_length, min_coverage=min_coverage, min_proportion=min_proportion, genome_length=genome_length, trim_min_length=trim_min_length, trim_quality_min_score=trim_quality_min_score, trim_window_size=trim_window_size, read_processing=read_processing, read_qc=read_qc, adapters=adapters, phix=phix, fastp_args=fastp_args, assembler=assembler, min_contig_length=min_contig_length, kmers=kmers, assembler_options=assembler_options, cg_pipe_opts=cg_pipe_opts, quast_min_contig_length=quast_min_contig_length, spades_type=spades_type, call_pilon=call_pilon, pilon_min_mapping_quality=pilon_min_mapping_quality, pilon_min_base_quality=pilon_min_base_quality, pilon_min_depth=pilon_min_depth, pilon_fix=pilon_fix, run_filter_contigs=run_filter_contigs, filter_contigs_min_length=filter_contigs_min_length, filter_contigs_min_coverage=filter_contigs_min_coverage, filter_contigs_skip_length_filter=filter_contigs_skip_length_filter, filter_contigs_skip_coverage_filter=filter_contigs_skip_coverage_filter, filter_contigs_skip_homopolymer_filter=filter_contigs_skip_homopolymer_filter, perform_characterization=perform_characterization, call_ani=call_ani, call_kmerfinder=call_kmerfinder, call_resfinder=call_resfinder, call_plasmidfinder=call_plasmidfinder, call_abricate=call_abricate, call_midas=call_midas, call_kraken=call_kraken, call_stxtyper=call_stxtyper, call_poppunk=call_poppunk, run_amr_search=run_amr_search, run_merlin_magic=run_merlin_magic, genome_annotation=genome_annotation, bakta_db=bakta_db, expected_taxon=expected_taxon, midas_db=midas_db, kraken_db=kraken_db, kmerfinder_db=kmerfinder_db, gambit_db_genomes=gambit_db_genomes, gambit_db_signatures=gambit_db_signatures, bakta_db_path=bakta_db_path, resfinder_db_res=resfinder_db_res, resfinder_db_point=resfinder_db_point, plasmidfinder_db=plasmidfinder_db, plasmidfinder_db_path=plasmidfinder_db_path, plasmidfinder_method_path=plasmidfinder_method_path, vibecheck_vibrio_barcodes=vibecheck_vibrio_barcodes, abricate_db=abricate_db, amrfinder_min_percent_identity=amrfinder_min_percent_identity, amrfinder_min_percent_coverage=amrfinder_min_percent_coverage, amrfinder_detailed_drug_class=amrfinder_detailed_drug_class, amrfinder_hide_point_mutations=amrfinder_hide_point_mutations, amrfinder_separate_betalactam_genes=amrfinder_separate_betalactam_genes, resfinder_organism=resfinder_organism, resfinder_acquired=resfinder_acquired, resfinder_min_percent_coverage=resfinder_min_percent_coverage, resfinder_min_percent_identity=resfinder_min_percent_identity, resfinder_call_pointfinder=resfinder_call_pointfinder, plasmidfinder_min_percent_coverage=plasmidfinder_min_percent_coverage, plasmidfinder_min_percent_identity=plasmidfinder_min_percent_identity, mlst_nopath=mlst_nopath, mlst_scheme=mlst_scheme, mlst_min_percent_identity=mlst_min_percent_identity, mlst_min_percent_coverage=mlst_min_percent_coverage, mlst_minscore=mlst_minscore, stxtyper_enable_debugging=stxtyper_enable_debugging, kaptive_start_end_margin=kaptive_start_end_margin, kaptive_min_percent_coverage=kaptive_min_percent_coverage, kaptive_min_percent_identity=kaptive_min_percent_identity, kaptive_low_gene_percent_identity=kaptive_low_gene_percent_identity, abricate_abaum_min_percent_identity=abricate_abaum_min_percent_identity, abricate_abaum_min_percent_coverage=abricate_abaum_min_percent_coverage, lissero_min_percent_identity=lissero_min_percent_identity, lissero_min_percent_coverage=lissero_min_percent_coverage, ectyper_o_min_percent_identity=ectyper_o_min_percent_identity, ectyper_h_min_percent_identity=ectyper_h_min_percent_identity, ectyper_o_min_percent_coverage=ectyper_o_min_percent_coverage, ectyper_h_min_percent_coverage=ectyper_h_min_percent_coverage, ectyper_verify=ectyper_verify, ectyper_print_alleles=ectyper_print_alleles, spatyper_do_enrich=spatyper_do_enrich, pbptyper_database=pbptyper_database, pbptyper_min_percent_identity=pbptyper_min_percent_identity, pbptyper_min_percent_coverage=pbptyper_min_percent_coverage, emmtyper_wf=emmtyper_wf, emmtyper_cluster_distance=emmtyper_cluster_distance, emmtyper_min_percent_identity=emmtyper_min_percent_identity, emmtyper_culling_limit=emmtyper_culling_limit, emmtyper_mismatch=emmtyper_mismatch, emmtyper_align_diff=emmtyper_align_diff, emmtyper_gap=emmtyper_gap, emmtyper_min_perfect=emmtyper_min_perfect, emmtyper_min_good=emmtyper_min_good, emmtyper_max_size=emmtyper_max_size, hicap_min_gene_percent_coverage=hicap_min_gene_percent_coverage, hicap_min_gene_depth=hicap_min_gene_depth, hicap_min_gene_length=hicap_min_gene_length, hicap_min_gene_percent_identity=hicap_min_gene_percent_identity, srst2_min_percent_coverage=srst2_min_percent_coverage, srst2_max_divergence=srst2_max_divergence, srst2_min_depth=srst2_min_depth, srst2_min_edge_depth=srst2_min_edge_depth, srst2_gene_max_mismatch=srst2_gene_max_mismatch, abricate_vibrio_min_percent_identity=abricate_vibrio_min_percent_identity, abricate_vibrio_min_percent_coverage=abricate_vibrio_min_percent_coverage, virulencefinder_database=virulencefinder_database, virulencefinder_min_percent_coverage=virulencefinder_min_percent_coverage, virulencefinder_min_percent_identity=virulencefinder_min_percent_identity, tbp_parser_config=tbp_parser_config, tbp_parser_sequencing_method=tbp_parser_sequencing_method, tbp_parser_operator=tbp_parser_operator, tbp_parser_min_depth=tbp_parser_min_depth, tbp_parser_min_frequency=tbp_parser_min_frequency, tbp_parser_min_read_support=tbp_parser_min_read_support, tbp_parser_min_percent_coverage=tbp_parser_min_percent_coverage, tbp_parser_coverage_regions_bed=tbp_parser_coverage_regions_bed, tbp_parser_add_cycloserine_lims=tbp_parser_add_cycloserine_lims, tbp_parser_debug=tbp_parser_debug, tbp_parser_tngs=tbp_parser_tngs, tbp_parser_rrs_frequncy=tbp_parser_rrs_frequncy, tbp_parser_rrs_read_support=tbp_parser_rrs_read_support, tbp_parser_rr1_frequency=tbp_parser_rr1_frequency, tbp_parser_rr1_read_support=tbp_parser_rr1_read_support, tbp_parser_rpob499_frequency=tbp_parser_rpob499_frequency, tbp_parser_etha237_frequency=tbp_parser_etha237_frequency, tbp_parser_expert_rule_regions_bed=tbp_parser_expert_rule_regions_bed, poppunk_gps_db_url=poppunk_gps_db_url, poppunk_gps_external_clusters_url=poppunk_gps_external_clusters_url, publish_dir_mode=publish_dir_mode, email=email, email_on_fail=email_on_fail, plaintext_email=plaintext_email, monochrome_logs=monochrome_logs, hook_url=hook_url, help_full=help_full, show_hidden=show_hidden, pipelines_testdata_base_path=pipelines_testdata_base_path, version=version, validate_params=validate_params, trace_report_suffix=trace_report_suffix)
    # upserting to latch
    process_results(run_flag=run_flag, input_samples=input, outdir=outdir, table_id=table_id, collated_data=collated_data)
    return outdir