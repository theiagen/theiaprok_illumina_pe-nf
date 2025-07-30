import sys
from dataclasses import dataclass
from enum import Enum
import os
import json
from typing import Dict
import subprocess
import requests
import shutil
from pathlib import Path
import typing
import typing_extensions

from latch import workflow, small_task
from latch.resources.tasks import nextflow_runtime_task, custom_task
from latch.types.file import LatchFile
from latch.types.directory import LatchDir, LatchOutputDir
from latch.ldata.path import LPath
from latch.executions import report_nextflow_used_storage
from latch_cli.nextflow.workflow import get_flag
from latch_cli.nextflow.utils import _get_execution_name
from latch_cli.utils import urljoins
from latch.types import metadata
from flytekit.core.annotation import FlyteAnnotation
from latch.executions import add_execution_results

from latch_cli.services.register.utils import import_module_by_path

meta = Path("latch_metadata") / "__init__.py"
import_module_by_path(meta)
import latch_metadata


@custom_task(cpu=0.25, memory=0.5, storage_gib=1)
def initialize() -> str:
    token = os.environ.get("FLYTE_INTERNAL_EXECUTION_ID")
    if token is None:
        raise RuntimeError("failed to get execution token")

    headers = {"Authorization": f"Latch-Execution-Token {token}"}

    print("Provisioning shared storage volume... ", end="")
    resp = requests.post(
        "http://nf-dispatcher-service.flyte.svc.cluster.local/provision-storage-ofs",
        headers=headers,
        json={
            "storage_expiration_hours": 168,
            "version": 2,
        },
    )
    resp.raise_for_status()
    print("Done.")

    return resp.json()["name"]

@dataclass
class Sample:
    sample: str
    read1: LatchFile
    read2: typing.Optional[LatchFile]

input_construct_samplesheet = metadata._nextflow_metadata.parameters['input'].samplesheet_constructor

@nextflow_runtime_task(cpu=8, memory=16, storage_gib=100)
def nextflow_runtime(table_id: int, pvc_name: str, input: typing.List[Sample], outdir: typing_extensions.Annotated[LatchDir, FlyteAnnotation({'output': True})], samplename: typing.Optional[str], read1: typing.Optional[str], read2: typing.Optional[str], ont_data: typing.Optional[bool], assembly_only: typing.Optional[bool], skip_screen: typing.Optional[bool], genome_length: typing.Optional[str], adapters: typing.Optional[str], phix: typing.Optional[str], kmers: typing.Optional[str], assembler_options: typing.Optional[str], cg_pipe_opts: typing.Optional[str], call_pilon: typing.Optional[bool], filter_contigs_skip_length_filter: typing.Optional[bool], filter_contigs_skip_coverage_filter: typing.Optional[bool], filter_contigs_skip_homopolymer_filter: typing.Optional[bool], call_ani: typing.Optional[bool], call_kmerfinder: typing.Optional[bool], call_resfinder: typing.Optional[bool], call_abricate: typing.Optional[bool], call_midas: typing.Optional[bool], call_stxtyper: typing.Optional[bool], call_poppunk: typing.Optional[bool], run_amr_search: typing.Optional[bool], expected_taxon: typing.Optional[str], resfinder_db_res: typing.Optional[str], resfinder_db_point: typing.Optional[str], plasmidfinder_db: typing.Optional[str], plasmidfinder_db_path: typing.Optional[str], plasmidfinder_method_path: typing.Optional[str], vibecheck_vibrio_barcodes: typing.Optional[str], amrfinder_detailed_drug_class: typing.Optional[bool], amrfinder_hide_point_mutations: typing.Optional[bool], amrfinder_separate_betalactam_genes: typing.Optional[bool], resfinder_organism: typing.Optional[str], resfinder_acquired: typing.Optional[bool], resfinder_call_pointfinder: typing.Optional[bool], mlst_nopath: typing.Optional[bool], mlst_scheme: typing.Optional[str], stxtyper_enable_debugging: typing.Optional[bool], ectyper_verify: typing.Optional[bool], ectyper_print_alleles: typing.Optional[bool], spatyper_do_enrich: typing.Optional[bool], tbp_parser_config: typing.Optional[str], tbp_parser_sequencing_method: typing.Optional[str], tbp_parser_operator: typing.Optional[str], tbp_parser_coverage_regions_bed: typing.Optional[str], tbp_parser_add_cycloserine_lims: typing.Optional[bool], tbp_parser_tngs: typing.Optional[bool], tbp_parser_expert_rule_regions_bed: typing.Optional[str], email: typing.Optional[str], email_on_fail: typing.Optional[str], plaintext_email: typing.Optional[bool], monochrome_logs: typing.Optional[bool], hook_url: typing.Optional[str], help_full: typing.Optional[bool], show_hidden: typing.Optional[bool], version: typing.Optional[bool], trace_report_suffix: typing.Optional[str], paired_end: typing.Optional[bool], workflow_series: typing.Optional[str], min_reads: typing.Optional[int], min_basepairs: typing.Optional[int], min_genome_length: typing.Optional[int], max_genome_length: typing.Optional[int], min_coverage: typing.Optional[int], min_proportion: typing.Optional[int], trim_min_length: typing.Optional[int], trim_quality_min_score: typing.Optional[int], trim_window_size: typing.Optional[int], read_processing: typing.Optional[str], read_qc: typing.Optional[str], fastp_args: typing.Optional[str], assembler: typing.Optional[str], min_contig_length: typing.Optional[int], quast_min_contig_length: typing.Optional[int], spades_type: typing.Optional[str], pilon_min_mapping_quality: typing.Optional[int], pilon_min_base_quality: typing.Optional[int], pilon_min_depth: typing.Optional[float], pilon_fix: typing.Optional[str], run_filter_contigs: typing.Optional[bool], filter_contigs_min_length: typing.Optional[int], filter_contigs_min_coverage: typing.Optional[int], perform_characterization: typing.Optional[bool], call_plasmidfinder: typing.Optional[bool], call_kraken: typing.Optional[bool], run_merlin_magic: typing.Optional[bool], genome_annotation: typing.Optional[str], bakta_db: typing.Optional[str], midas_db: typing.Optional[str], kraken_db: typing.Optional[str], kmerfinder_db: typing.Optional[str], gambit_db_genomes: typing.Optional[str], gambit_db_signatures: typing.Optional[str], bakta_db_path: typing.Optional[str], abricate_db: typing.Optional[str], amrfinder_min_percent_identity: typing.Optional[float], amrfinder_min_percent_coverage: typing.Optional[float], resfinder_min_percent_coverage: typing.Optional[float], resfinder_min_percent_identity: typing.Optional[float], plasmidfinder_min_percent_coverage: typing.Optional[float], plasmidfinder_min_percent_identity: typing.Optional[float], mlst_min_percent_identity: typing.Optional[int], mlst_min_percent_coverage: typing.Optional[int], mlst_minscore: typing.Optional[int], kaptive_start_end_margin: typing.Optional[int], kaptive_min_percent_coverage: typing.Optional[int], kaptive_min_percent_identity: typing.Optional[int], kaptive_low_gene_percent_identity: typing.Optional[int], abricate_abaum_min_percent_identity: typing.Optional[int], abricate_abaum_min_percent_coverage: typing.Optional[int], lissero_min_percent_identity: typing.Optional[int], lissero_min_percent_coverage: typing.Optional[int], ectyper_o_min_percent_identity: typing.Optional[int], ectyper_h_min_percent_identity: typing.Optional[int], ectyper_o_min_percent_coverage: typing.Optional[int], ectyper_h_min_percent_coverage: typing.Optional[int], pbptyper_database: typing.Optional[str], pbptyper_min_percent_identity: typing.Optional[int], pbptyper_min_percent_coverage: typing.Optional[int], emmtyper_wf: typing.Optional[str], emmtyper_cluster_distance: typing.Optional[int], emmtyper_min_percent_identity: typing.Optional[int], emmtyper_culling_limit: typing.Optional[int], emmtyper_mismatch: typing.Optional[int], emmtyper_align_diff: typing.Optional[int], emmtyper_gap: typing.Optional[int], emmtyper_min_perfect: typing.Optional[int], emmtyper_min_good: typing.Optional[int], emmtyper_max_size: typing.Optional[int], hicap_min_gene_percent_coverage: typing.Optional[float], hicap_min_gene_depth: typing.Optional[float], hicap_min_gene_length: typing.Optional[int], hicap_min_gene_percent_identity: typing.Optional[float], srst2_min_percent_coverage: typing.Optional[int], srst2_max_divergence: typing.Optional[int], srst2_min_depth: typing.Optional[int], srst2_min_edge_depth: typing.Optional[int], srst2_gene_max_mismatch: typing.Optional[int], abricate_vibrio_min_percent_identity: typing.Optional[int], abricate_vibrio_min_percent_coverage: typing.Optional[int], virulencefinder_database: typing.Optional[str], virulencefinder_min_percent_coverage: typing.Optional[float], virulencefinder_min_percent_identity: typing.Optional[float], tbp_parser_min_depth: typing.Optional[int], tbp_parser_min_frequency: typing.Optional[float], tbp_parser_min_read_support: typing.Optional[int], tbp_parser_min_percent_coverage: typing.Optional[int], tbp_parser_debug: typing.Optional[bool], tbp_parser_rrs_frequncy: typing.Optional[float], tbp_parser_rrs_read_support: typing.Optional[int], tbp_parser_rr1_frequency: typing.Optional[float], tbp_parser_rr1_read_support: typing.Optional[int], tbp_parser_rpob499_frequency: typing.Optional[float], tbp_parser_etha237_frequency: typing.Optional[float], poppunk_gps_db_url: typing.Optional[str], poppunk_gps_external_clusters_url: typing.Optional[str], publish_dir_mode: typing.Optional[str], pipelines_testdata_base_path: typing.Optional[str], validate_params: typing.Optional[bool]) -> tuple[bool, str]:
    root_dir = Path("/root")
    shared_dir = Path("/nf-workdir")

    exec_name = _get_execution_name()
    if exec_name is None:
        print("Failed to get execution name.")
        exec_name = "unknown"

    latch_log_dir = urljoins("latch:///theiaprok_pe_log/nf_theiaprok_illumina_pe", exec_name)
    print(f"Log directory: {latch_log_dir}")


    input_samplesheet = input_construct_samplesheet(input)

    to_ignore = {
        "latch",
        ".latch",
        ".git",
        "nextflow",
        ".nextflow",
        "work",
        "results",
        "miniconda",
        "anaconda3",
        "mambaforge",
    }

    for p in root_dir.iterdir():
        if p.name in to_ignore:
            continue

        src = root_dir / p.name
        target = shared_dir / p.name

        if p.is_dir():
            shutil.copytree(
                src,
                target,
                ignore_dangling_symlinks=True,
                dirs_exist_ok=True,
            )
        else:
            shutil.copy2(src, target)

    profile_list = ['docker']
    if False:
        profile_list.extend([p.value for p in execution_profiles])

    if len(profile_list) == 0:
        profile_list.append("standard")

    profiles = ','.join(profile_list)

    cmd = [
        "/root/nextflow",
        "run",
        str(shared_dir / "main.nf"),
        "-work-dir",
        str(shared_dir),
        "-profile",
        profiles,
        "-c",
        "latch.config",
        "-resume",
        *get_flag('input', input_samplesheet),
                *get_flag('outdir', outdir),
                *get_flag('samplename', samplename),
                *get_flag('read1', read1),
                *get_flag('read2', read2),
                *get_flag('paired_end', paired_end),
                *get_flag('ont_data', ont_data),
                *get_flag('assembly_only', assembly_only),
                *get_flag('skip_screen', skip_screen),
                *get_flag('workflow_series', workflow_series),
                *get_flag('min_reads', min_reads),
                *get_flag('min_basepairs', min_basepairs),
                *get_flag('min_genome_length', min_genome_length),
                *get_flag('max_genome_length', max_genome_length),
                *get_flag('min_coverage', min_coverage),
                *get_flag('min_proportion', min_proportion),
                *get_flag('genome_length', genome_length),
                *get_flag('trim_min_length', trim_min_length),
                *get_flag('trim_quality_min_score', trim_quality_min_score),
                *get_flag('trim_window_size', trim_window_size),
                *get_flag('read_processing', read_processing),
                *get_flag('read_qc', read_qc),
                *get_flag('adapters', adapters),
                *get_flag('phix', phix),
                *get_flag('fastp_args', fastp_args),
                *get_flag('assembler', assembler),
                *get_flag('min_contig_length', min_contig_length),
                *get_flag('kmers', kmers),
                *get_flag('assembler_options', assembler_options),
                *get_flag('cg_pipe_opts', cg_pipe_opts),
                *get_flag('quast_min_contig_length', quast_min_contig_length),
                *get_flag('spades_type', spades_type),
                *get_flag('call_pilon', call_pilon),
                *get_flag('pilon_min_mapping_quality', pilon_min_mapping_quality),
                *get_flag('pilon_min_base_quality', pilon_min_base_quality),
                *get_flag('pilon_min_depth', pilon_min_depth),
                *get_flag('pilon_fix', pilon_fix),
                *get_flag('run_filter_contigs', run_filter_contigs),
                *get_flag('filter_contigs_min_length', filter_contigs_min_length),
                *get_flag('filter_contigs_min_coverage', filter_contigs_min_coverage),
                *get_flag('filter_contigs_skip_length_filter', filter_contigs_skip_length_filter),
                *get_flag('filter_contigs_skip_coverage_filter', filter_contigs_skip_coverage_filter),
                *get_flag('filter_contigs_skip_homopolymer_filter', filter_contigs_skip_homopolymer_filter),
                *get_flag('perform_characterization', perform_characterization),
                *get_flag('call_ani', call_ani),
                *get_flag('call_kmerfinder', call_kmerfinder),
                *get_flag('call_resfinder', call_resfinder),
                *get_flag('call_plasmidfinder', call_plasmidfinder),
                *get_flag('call_abricate', call_abricate),
                *get_flag('call_midas', call_midas),
                *get_flag('call_kraken', call_kraken),
                *get_flag('call_stxtyper', call_stxtyper),
                *get_flag('call_poppunk', call_poppunk),
                *get_flag('run_amr_search', run_amr_search),
                *get_flag('run_merlin_magic', run_merlin_magic),
                *get_flag('genome_annotation', genome_annotation),
                *get_flag('bakta_db', bakta_db),
                *get_flag('expected_taxon', expected_taxon),
                *get_flag('midas_db', midas_db),
                *get_flag('kraken_db', kraken_db),
                *get_flag('kmerfinder_db', kmerfinder_db),
                *get_flag('gambit_db_genomes', gambit_db_genomes),
                *get_flag('gambit_db_signatures', gambit_db_signatures),
                *get_flag('bakta_db_path', bakta_db_path),
                *get_flag('resfinder_db_res', resfinder_db_res),
                *get_flag('resfinder_db_point', resfinder_db_point),
                *get_flag('plasmidfinder_db', plasmidfinder_db),
                *get_flag('plasmidfinder_db_path', plasmidfinder_db_path),
                *get_flag('plasmidfinder_method_path', plasmidfinder_method_path),
                *get_flag('vibecheck_vibrio_barcodes', vibecheck_vibrio_barcodes),
                *get_flag('abricate_db', abricate_db),
                *get_flag('amrfinder_min_percent_identity', amrfinder_min_percent_identity),
                *get_flag('amrfinder_min_percent_coverage', amrfinder_min_percent_coverage),
                *get_flag('amrfinder_detailed_drug_class', amrfinder_detailed_drug_class),
                *get_flag('amrfinder_hide_point_mutations', amrfinder_hide_point_mutations),
                *get_flag('amrfinder_separate_betalactam_genes', amrfinder_separate_betalactam_genes),
                *get_flag('resfinder_organism', resfinder_organism),
                *get_flag('resfinder_acquired', resfinder_acquired),
                *get_flag('resfinder_min_percent_coverage', resfinder_min_percent_coverage),
                *get_flag('resfinder_min_percent_identity', resfinder_min_percent_identity),
                *get_flag('resfinder_call_pointfinder', resfinder_call_pointfinder),
                *get_flag('plasmidfinder_min_percent_coverage', plasmidfinder_min_percent_coverage),
                *get_flag('plasmidfinder_min_percent_identity', plasmidfinder_min_percent_identity),
                *get_flag('mlst_nopath', mlst_nopath),
                *get_flag('mlst_scheme', mlst_scheme),
                *get_flag('mlst_min_percent_identity', mlst_min_percent_identity),
                *get_flag('mlst_min_percent_coverage', mlst_min_percent_coverage),
                *get_flag('mlst_minscore', mlst_minscore),
                *get_flag('stxtyper_enable_debugging', stxtyper_enable_debugging),
                *get_flag('kaptive_start_end_margin', kaptive_start_end_margin),
                *get_flag('kaptive_min_percent_coverage', kaptive_min_percent_coverage),
                *get_flag('kaptive_min_percent_identity', kaptive_min_percent_identity),
                *get_flag('kaptive_low_gene_percent_identity', kaptive_low_gene_percent_identity),
                *get_flag('abricate_abaum_min_percent_identity', abricate_abaum_min_percent_identity),
                *get_flag('abricate_abaum_min_percent_coverage', abricate_abaum_min_percent_coverage),
                *get_flag('lissero_min_percent_identity', lissero_min_percent_identity),
                *get_flag('lissero_min_percent_coverage', lissero_min_percent_coverage),
                *get_flag('ectyper_o_min_percent_identity', ectyper_o_min_percent_identity),
                *get_flag('ectyper_h_min_percent_identity', ectyper_h_min_percent_identity),
                *get_flag('ectyper_o_min_percent_coverage', ectyper_o_min_percent_coverage),
                *get_flag('ectyper_h_min_percent_coverage', ectyper_h_min_percent_coverage),
                *get_flag('ectyper_verify', ectyper_verify),
                *get_flag('ectyper_print_alleles', ectyper_print_alleles),
                *get_flag('spatyper_do_enrich', spatyper_do_enrich),
                *get_flag('pbptyper_database', pbptyper_database),
                *get_flag('pbptyper_min_percent_identity', pbptyper_min_percent_identity),
                *get_flag('pbptyper_min_percent_coverage', pbptyper_min_percent_coverage),
                *get_flag('emmtyper_wf', emmtyper_wf),
                *get_flag('emmtyper_cluster_distance', emmtyper_cluster_distance),
                *get_flag('emmtyper_min_percent_identity', emmtyper_min_percent_identity),
                *get_flag('emmtyper_culling_limit', emmtyper_culling_limit),
                *get_flag('emmtyper_mismatch', emmtyper_mismatch),
                *get_flag('emmtyper_align_diff', emmtyper_align_diff),
                *get_flag('emmtyper_gap', emmtyper_gap),
                *get_flag('emmtyper_min_perfect', emmtyper_min_perfect),
                *get_flag('emmtyper_min_good', emmtyper_min_good),
                *get_flag('emmtyper_max_size', emmtyper_max_size),
                *get_flag('hicap_min_gene_percent_coverage', hicap_min_gene_percent_coverage),
                *get_flag('hicap_min_gene_depth', hicap_min_gene_depth),
                *get_flag('hicap_min_gene_length', hicap_min_gene_length),
                *get_flag('hicap_min_gene_percent_identity', hicap_min_gene_percent_identity),
                *get_flag('srst2_min_percent_coverage', srst2_min_percent_coverage),
                *get_flag('srst2_max_divergence', srst2_max_divergence),
                *get_flag('srst2_min_depth', srst2_min_depth),
                *get_flag('srst2_min_edge_depth', srst2_min_edge_depth),
                *get_flag('srst2_gene_max_mismatch', srst2_gene_max_mismatch),
                *get_flag('abricate_vibrio_min_percent_identity', abricate_vibrio_min_percent_identity),
                *get_flag('abricate_vibrio_min_percent_coverage', abricate_vibrio_min_percent_coverage),
                *get_flag('virulencefinder_database', virulencefinder_database),
                *get_flag('virulencefinder_min_percent_coverage', virulencefinder_min_percent_coverage),
                *get_flag('virulencefinder_min_percent_identity', virulencefinder_min_percent_identity),
                *get_flag('tbp_parser_config', tbp_parser_config),
                *get_flag('tbp_parser_sequencing_method', tbp_parser_sequencing_method),
                *get_flag('tbp_parser_operator', tbp_parser_operator),
                *get_flag('tbp_parser_min_depth', tbp_parser_min_depth),
                *get_flag('tbp_parser_min_frequency', tbp_parser_min_frequency),
                *get_flag('tbp_parser_min_read_support', tbp_parser_min_read_support),
                *get_flag('tbp_parser_min_percent_coverage', tbp_parser_min_percent_coverage),
                *get_flag('tbp_parser_coverage_regions_bed', tbp_parser_coverage_regions_bed),
                *get_flag('tbp_parser_add_cycloserine_lims', tbp_parser_add_cycloserine_lims),
                *get_flag('tbp_parser_debug', tbp_parser_debug),
                *get_flag('tbp_parser_tngs', tbp_parser_tngs),
                *get_flag('tbp_parser_rrs_frequncy', tbp_parser_rrs_frequncy),
                *get_flag('tbp_parser_rrs_read_support', tbp_parser_rrs_read_support),
                *get_flag('tbp_parser_rr1_frequency', tbp_parser_rr1_frequency),
                *get_flag('tbp_parser_rr1_read_support', tbp_parser_rr1_read_support),
                *get_flag('tbp_parser_rpob499_frequency', tbp_parser_rpob499_frequency),
                *get_flag('tbp_parser_etha237_frequency', tbp_parser_etha237_frequency),
                *get_flag('tbp_parser_expert_rule_regions_bed', tbp_parser_expert_rule_regions_bed),
                *get_flag('poppunk_gps_db_url', poppunk_gps_db_url),
                *get_flag('poppunk_gps_external_clusters_url', poppunk_gps_external_clusters_url),
                *get_flag('publish_dir_mode', publish_dir_mode),
                *get_flag('email', email),
                *get_flag('email_on_fail', email_on_fail),
                *get_flag('plaintext_email', plaintext_email),
                *get_flag('monochrome_logs', monochrome_logs),
                *get_flag('hook_url', hook_url),
                *get_flag('help_full', help_full),
                *get_flag('show_hidden', show_hidden),
                *get_flag('pipelines_testdata_base_path', pipelines_testdata_base_path),
                *get_flag('version', version),
                *get_flag('validate_params', validate_params),
                *get_flag('trace_report_suffix', trace_report_suffix)
    ]

    print("Launching Nextflow Runtime")
    print(' '.join(cmd))
    print(flush=True)

    failed = False
    passed = True
    try:
        env = {
            **os.environ,
            "NXF_ANSI_LOG": "false",
            "NXF_HOME": "/root/.nextflow",
            "NXF_OPTS": "-Xms1536M -Xmx6144M -XX:ActiveProcessorCount=4",
            "NXF_DISABLE_CHECK_LATEST": "true",
            "NXF_ENABLE_VIRTUAL_THREADS": "false",
            "NXF_ENABLE_FS_SYNC": "true",
        }

        if False:
            env["LATCH_LOG_DIR"] = latch_log_dir

        subprocess.run(
            cmd,
            env=env,
            check=True,
            cwd=str(shared_dir),
        )
    except subprocess.CalledProcessError:
        failed = True
        passed = False
    finally:
        print()

        nextflow_log = shared_dir / ".nextflow.log"
        if nextflow_log.exists():
            remote = LPath(urljoins(latch_log_dir, "nextflow.log"))
            print(f"Uploading .nextflow.log to {remote.path}")
            remote.upload_from(nextflow_log)

            collated_json = shared_dir / "reportfile" / "collated-workflow-files.json"
            print(f"Parsing Collated JSON Results at {collated_json}")
            with open(collated_json, 'r') as f: 
                collated_data = json.load(f)
                print(f"Collated JSON Results: {collated_data}")
            collated_data = json.dumps(collated_data)

        print("Computing size of workdir... ", end="")
        try:
            result = subprocess.run(
                ['du', '-sb', str(shared_dir)],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=5 * 60
            )

            size = int(result.stdout.split()[0])
            report_nextflow_used_storage(size)
            print(f"Done. Workdir size: {size / 1024 / 1024 / 1024: .2f} GiB")
        except subprocess.TimeoutExpired:
            print("Failed to compute storage size: Operation timed out after 5 minutes.")
        except subprocess.CalledProcessError as e:
            print(f"Failed to compute storage size: {e.stderr}")
        except Exception as e:
            print(f"Failed to compute storage size: {e}")

    if failed:
        sys.exit(1)

    return passed, collated_data