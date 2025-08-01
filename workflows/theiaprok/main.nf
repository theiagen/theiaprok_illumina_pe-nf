// Let's get the subworkflows in here
include { DIGGER_DENOVO } from '../../subworkflows/local/utilities/digger_denovo/main'
include { READ_QC_TRIM_PE } from '../../subworkflows/local/utilities/read_QC_trim_pe/main'
include { MERLIN_MAGIC } from '../../subworkflows/local/utilities/merlin_magic/main'
// And let's get the modules
include { CHECK_READS as RAW_CHECK_READS } from '../../modules/local/quality_control/comparison/task_screen/main'
include { CHECK_READS as CLEAN_CHECK_READS } from '../../modules/local/quality_control/comparison/task_screen/main'
include { QUAST } from '../../modules/local/quality_control/basic_statistics/quast/main'
include { CG_PIPELINE as CG_PIPELINE_RAW } from '../../modules/local/quality_control/basic_statistics/cg_pipeline/main'
include { CG_PIPELINE as CG_PIPELINE_CLEAN } from '../../modules/local/quality_control/basic_statistics/cg_pipeline/main'
include { BUSCO } from '../../modules/local/quality_control/advanced_metrics/busco/main'
include { GAMBIT } from '../../modules/local/taxon_id/gambit/main'
include { ANI_MUMMER } from '../../modules/local/quality_control/advanced_metrics/animummer/main'
include { KMERFINDER_BACTERIA } from '../../modules/local/taxon_id/contamination/kmerfinder/main'
include { AMRFINDER_PLUS_NUC } from '../../modules/local/gene_typing/drug_resistance/amrfinderplus/main'
include { RESFINDER } from '../../modules/local/gene_typing/drug_resistance/resfinder/main'
include { TS_MLST } from '../../modules/local/species_typing/multi/ts_mlst/main'
include { PROKKA } from '../../modules/nf-core/prokka/main'
include { BAKTA_BAKTA as BAKTA } from '../../modules/nf-core/bakta/bakta/main'
include { PLASMIDFINDER } from '../../modules/local/gene_typing/plasmid_detection/plasmidfinder/main'
include { ABRICATE } from '../../modules/local/gene_typing/drug_resistance/abricate/main'
include { UTILITY_JSON_BUILDER } from '../../modules/local/utilities/json_builder/main'

// Failure report module for "soft" failures
include { CREATE_FAILURE_REPORT } from '../../modules/local/reports/failure/main'
workflow THEIAPROK_ILLUMINA_PE {
    
    take:
    ch_reads // channel: [ val(meta), path(read1), path(read2) ]
    
    main:
    
    ch_versions = Channel.empty()
    
    // Dumping all the defualt parameters here for now
    def seq_method = params.seq_method ?: "ILLUMINA" // Probably not necessary, relic of wdl implementation
    def skip_screen = params.skip_screen ?: false
    def min_reads = params.min_reads ?: 7472
    def min_basepairs = params.min_basepairs ?: 2241820
    def min_genome_length = params.min_genome_length ?: 100000
    def max_genome_length = params.max_genome_length ?: 18040666
    def min_coverage = params.min_coverage ?: 10
    def min_proportion = params.min_proportion ?: 40
    def trim_min_length = params.trim_min_length ?: 75
    def trim_quality_min_score = params.trim_quality_min_score ?: 20
    def trim_window_size = params.trim_window_size ?: 10
    def perform_characterization = params.perform_characterization ?: true
    def call_ani = params.call_ani ?: false
    def call_kmerfinder = params.call_kmerfinder ?: false
    def call_resfinder = params.call_resfinder ?: false
    def call_plasmidfinder = params.call_plasmidfinder ?: true
    def call_abricate = params.call_abricate ?: false
    def abricate_db = params.abricate_db ?: "vfdb"
    def genome_annotation = params.genome_annotation ?: "prokka"
    def bakta_db = params.bakta_db ?: "full"
    
    ch_assembly = Channel.empty()
    ch_read_screen_raw = Channel.empty()
    ch_read_screen_clean = Channel.empty()
    ch_value_outputs = Channel.empty()
    
    ch_estimated_genome_length = Channel.empty()
    ch_clean_reads = Channel.empty()
    ch_quast_report = Channel.empty()
    ch_cg_pipeline_raw = Channel.empty()
    ch_cg_pipeline_clean = Channel.empty()
    ch_busco_report = Channel.empty()
    ch_busco_results = Channel.empty()
    
    // Capture failed samples -- based on our criteria
    ch_failed_samples = Channel.empty()

    if (!skip_screen) {
        RAW_CHECK_READS (
            ch_reads,
            min_reads,
            min_basepairs,
            min_genome_length,
            max_genome_length,
            min_coverage,
            min_proportion,
            "theiaprok",
            params.genome_length ?: "",
            "raw"
        )
        ch_read_screen_raw = RAW_CHECK_READS.out.read_screen
        ch_value_outputs = RAW_CHECK_READS.out.read_screen_value_results
        ch_versions = ch_versions.mix(RAW_CHECK_READS.out.versions)
        ch_reads
            .join(ch_read_screen_raw)
            .branch { meta, reads, screen_result ->
                pass: screen_result.text.trim() == "PASS"
                    return [meta, reads]
                fail: screen_result.text.trim() != "PASS"
                    return [meta, reads, screen_result, "RAW_SCREEN_FAIL"]
            }
            .set { ch_raw_screen_branch }

        ch_reads_to_process = ch_raw_screen_branch.pass
        ch_failed_samples = ch_failed_samples.mix(ch_raw_screen_branch.fail)

    } else {
        ch_reads_to_process = ch_reads
    }
    
    // Read QC and trimming
    READ_QC_TRIM_PE (
        ch_reads_to_process,
        trim_min_length,
        trim_quality_min_score,
        trim_window_size,
        params.call_midas ?: false,
        params.midas_db ?: [],
        params.call_kraken ?: false,
        params.kraken_db ?: [],
        params.adapters ?: [],
        params.phix ?: [],
        "theiaprok",
        params.read_processing ?: "trimmomatic",
        params.read_qc ?: "fastq_scan",
        params.trimmomatic_args ?: "",
        params.fastp_args ?: ""
    )
    ch_value_outputs = ch_value_outputs.mix(READ_QC_TRIM_PE.out.value_results)
    ch_versions = ch_versions.mix(READ_QC_TRIM_PE.out.versions)
    
    ch_clean_reads = READ_QC_TRIM_PE.out.bbduk_cleaned_reads
    
    if (!skip_screen) {
        CLEAN_CHECK_READS (
            ch_clean_reads,
            min_reads,
            min_basepairs,
            min_genome_length,
            max_genome_length,
            min_coverage,
            min_proportion,
            "theiaprok",
            params.genome_length ?: "",
            "clean"
        )
        ch_read_screen_clean = CLEAN_CHECK_READS.out.read_screen
        ch_value_outputs = ch_value_outputs.mix(CLEAN_CHECK_READS.out.read_screen_value_results)
        ch_versions = ch_versions.mix(CLEAN_CHECK_READS.out.versions)
        
        // Split channels for processing passing and failure samples
        ch_clean_reads
            .join(ch_read_screen_clean)
            .branch { meta, reads, screen_result ->
                pass: screen_result.text.trim() == "PASS"
                    return [meta, reads]
                fail: screen_result.text.trim() != "PASS"
                    return [meta, reads, screen_result, "CLEAN_SCREEN_FAIL"]
            }
            .set { ch_clean_screen_branch }
        
        ch_clean_reads_to_process = ch_clean_screen_branch.pass
        ch_failed_samples = ch_failed_samples.mix(ch_clean_screen_branch.fail)
    } else {
        ch_clean_reads_to_process = ch_clean_reads
    }
    
    // Assembly and downstream analysis
    DIGGER_DENOVO (
        ch_clean_reads_to_process
    )
    ch_assembly = DIGGER_DENOVO.out.assembly
    ch_versions = ch_versions.mix(DIGGER_DENOVO.out.versions)
    
    // Check for assembly failures
    ch_assembly
        .branch { meta, assembly ->
            pass: assembly && assembly.exists() && assembly.size() > 0
                return [meta, assembly]
            fail: true
                return [meta, [], "ASSEMBLY_FAIL"]
        }
        .set { ch_assembly_branch }

    ch_assembly = ch_assembly_branch.pass
    // If assembly failed, add to failed samples with a reason
    // This is a "soft" failure, we still want to run the rest of the workflow
    ch_failed_samples = ch_failed_samples.mix(
        ch_assembly_branch.fail.map { meta, assembly, fail_type ->
            [meta, [], fail_type, "Assembly failed or produced empty output"]
        }
    )
    
    QUAST (
        ch_assembly
    )
    ch_quast_report = QUAST.out.report
    ch_versions = ch_versions.mix(QUAST.out.versions)
    
    // Get genome length for coverage calculations, can refactore later
    ch_genome_length_for_cg = ch_assembly
        .join(ch_quast_report)
        .map { meta, assembly, report ->
            def genome_length = report.text.readLines()
                .find { it ==~ /^Total length\t.*/ }
                ?.split(/\t/)[1] ?: params.genome_length ?: "3000000"
            [meta, genome_length as Integer]
        }
    
    // CG Pipeline for raw reads
    ch_cg_raw_input = ch_reads
        .join(ch_genome_length_for_cg, by: 0, remainder: true)
        .map { meta, reads, genome_length ->
            [meta, reads]
        }

    CG_PIPELINE_RAW (
        ch_cg_raw_input,
        params.genome_length ?: 3000000,
        params.cg_pipe_opts ?: "",
        "raw"
    )
    ch_value_outputs = ch_value_outputs.mix(CG_PIPELINE_RAW.out.cg_pipeline_value_results)
    ch_cg_pipeline_raw = CG_PIPELINE_RAW.out.cg_pipeline_report
    ch_versions = ch_versions.mix(CG_PIPELINE_RAW.out.versions)
    
    ch_cg_clean_input = ch_clean_reads
        .join(ch_genome_length_for_cg, by: 0, remainder: true)
        .map { meta, reads, genome_length ->
            [meta, reads]
        }
    
    CG_PIPELINE_CLEAN (
        ch_cg_clean_input,
        params.genome_length ?: 3000000,
        params.cg_pipe_opts ?: "",
        "clean"
    )
    ch_value_outputs = ch_value_outputs.mix(CG_PIPELINE_CLEAN.out.cg_pipeline_value_results)
    ch_cg_pipeline_clean = CG_PIPELINE_CLEAN.out.cg_pipeline_report
    ch_versions = ch_versions.mix(CG_PIPELINE_CLEAN.out.versions)
    
    BUSCO (
        ch_assembly,
        false  // eukaryote = false for bacteria
    )
    ch_busco_report = BUSCO.out.busco_report
    ch_busco_results = BUSCO.out.busco_value_results
    ch_versions = ch_versions.mix(BUSCO.out.versions)
    ch_value_outputs = ch_value_outputs.mix(BUSCO.out.busco_value_results)

    if (perform_characterization) {
        GAMBIT (
            ch_assembly,
            params.gambit_db_genomes,
            params.gambit_db_signatures
        )
        ch_value_outputs = ch_value_outputs.mix(GAMBIT.out.gambit_value_results)
        ch_versions = ch_versions.mix(GAMBIT.out.versions)
        
        // Get organism/merlin tag with better handling
        ch_organism_and_tag = ch_assembly
            .join(GAMBIT.out.predicted_taxon, by: 0, remainder: true)
            .join(GAMBIT.out.merlin_tag, by: 0, remainder: true)
            .map { meta, assembly, taxon, merlin_tag_file ->
                // Extract organism from taxon
                def organism = params.expected_taxon ?: taxon ?: ""
                
                // Extract merlin_tag from file or use taxon
                def merlin_tag = ""
                if (params.expected_taxon) {
                    merlin_tag = params.expected_taxon
                } else if (merlin_tag_file && merlin_tag_file.exists() && merlin_tag_file.size() > 0) {
                    try {
                        merlin_tag = merlin_tag_file.text.trim()
                    } catch (Exception e) {
                        log.warn "Could not read merlin_tag file for ${meta.id}: ${e.message}"
                        // Fall back to taxon
                        merlin_tag = taxon ?: ""
                    }
                } else {
                    // If no merlin_tag file, use the taxon as merlin_tag
                    merlin_tag = taxon ?: ""
                }
                
                log.info "Sample ${meta.id}: organism='${organism}', merlin_tag='${merlin_tag}'"
                [meta, organism, merlin_tag]
            }
        
        // Split organism and merlin_tag for different uses
        ch_organism = ch_organism_and_tag.map { meta, organism, merlin_tag -> [meta, organism] }
        
        if (call_ani) {
            ANI_MUMMER (
                ch_assembly,
                params.ani_ref_genome ?: []
            )
            ch_value_outputs = ch_value_outputs.mix(ANI_MUMMER.out.txt)
            ch_versions = ch_versions.mix(ANI_MUMMER.out.versions)
        }
        
        if (call_kmerfinder) {
            KMERFINDER_BACTERIA (
                ch_assembly,
                params.kmerfinder_db ?: []
            )
            ch_value_outputs = ch_value_outputs.mix(KMERFINDER_BACTERIA.out.kmerfinder_value_results)
            ch_versions = ch_versions.mix(KMERFINDER_BACTERIA.out.versions)
        }
        
        ch_amrfinder_input = ch_assembly
            .join(ch_organism, by: 0)
        
        AMRFINDER_PLUS_NUC (
            ch_amrfinder_input.map { meta, assembly, organism -> [meta, assembly] },
            ch_amrfinder_input.map { meta, assembly, organism -> organism }
        )
        ch_value_outputs = ch_value_outputs.mix(AMRFINDER_PLUS_NUC.out.amrfinderplus_value_results)
        ch_versions = ch_versions.mix(AMRFINDER_PLUS_NUC.out.versions)
        
        if (call_resfinder) {
            RESFINDER (
                ch_amrfinder_input.map { meta, assembly, organism -> [meta, assembly] },
                params.resfinder_db_point ?: [],
                params.resfinder_db_res ?: []
            )
            ch_value_outputs = ch_value_outputs.mix(RESFINDER.out.resfinder_predicted_resistance)
            ch_versions = ch_versions.mix(RESFINDER.out.versions)
        }

        ch_mlst_input = ch_assembly
            .join(ch_organism, by: 0)
        
        TS_MLST (
            ch_mlst_input.map { meta, assembly, organism -> [meta, assembly] },
            params.mlst_nopath ?: false,
            params.mlst_scheme ?: "",
            ch_mlst_input.map { meta, assembly, organism -> organism },
            params.mlst_min_percent_identity ?: 95,
            params.mlst_min_percent_coverage ?: 10,
            params.mlst_minscore ?: 50
        )
        ch_value_outputs = ch_value_outputs.mix(TS_MLST.out.ts_mlst_value_results)
        ch_versions = ch_versions.mix(TS_MLST.out.versions)
        
        if (genome_annotation == "prokka") {
            PROKKA (
                ch_assembly,
                [],
                []
            )
            ch_versions = ch_versions.mix(PROKKA.out.versions)
        }
        
        if (genome_annotation == "bakta") {
            ch_bakta_db = Channel.empty()
            if (bakta_db == "light") {
                ch_bakta_db = Channel.fromPath("${params.bakta_db_path}/bakta_db_light_2025-01-23.tar.gz")
            } else if (bakta_db == "full") {
                ch_bakta_db = Channel.fromPath("${params.bakta_db_path}/bakta_db_full_2024-01-23.tar.gz")
            } else {
                ch_bakta_db = Channel.fromPath(bakta_db)
            }
            
            BAKTA (
                ch_assembly,
                ch_bakta_db.collect(),
                [],
                []
            )
            ch_versions = ch_versions.mix(BAKTA.out.versions)
        }
        
        if (call_plasmidfinder) {
            PLASMIDFINDER (
                ch_assembly,
                params.plasmidfinder_db ?: [],
                params.plasmidfinder_db_path ?: [],
                params.plasmidfinder_method_path ?: [],
                params.plasmidfinder_min_percent_coverage ?: 0.60,
                params.plasmidfinder_min_percent_identity ?: 0.90
            )
            ch_value_outputs = ch_value_outputs.mix(PLASMIDFINDER.out.plasmidfinder_plasmids)
            ch_versions = ch_versions.mix(PLASMIDFINDER.out.versions)
        }
        
        if (call_abricate) {
            ABRICATE (
                ch_assembly,
                abricate_db,
                params.abricate_min_percent_identity ?: 80,
                params.abricate_min_percent_coverage ?: 80
            )
            ch_value_outputs = ch_value_outputs.mix(ABRICATE.out.genes_file)
            ch_versions = ch_versions.mix(ABRICATE.out.versions)
        }

        if (params.run_merlin_magic ?: true) {
            // Create channel with sample data and merlin_tag for each sample
            ch_merlin_input = ch_assembly
                .join(ch_clean_reads, by: 0)
                .join(GAMBIT.out.merlin_tag, by: 0, remainder: true)
                .map { meta, assembly, reads, tag_file ->
                    // Extract the merlin tag
                    def merlin_tag = ""
                    if (tag_file && tag_file.exists()) {
                        merlin_tag = tag_file.text.trim()
                    }
                    def final_tag = params.expected_taxon ?: merlin_tag ?: ""
                    log.info "Sample ${meta.id} has merlin_tag: '${final_tag}'"
                    return [meta, assembly, reads, final_tag]  // Return the tuple format expected by MERLIN_MAGIC
                }
                .view { meta, assembly, reads, tag -> "MERLIN input: ${meta.id} -> tag='${tag}'" }
                .filter { meta, assembly, reads, tag ->
                    def pass = tag && tag != "" && tag != "unknown"
                    if (!pass) {
                        log.warn "Sample ${meta.id} filtered out: tag='${tag}'"
                    }
                    return pass
                }
            MERLIN_MAGIC(
                ch_merlin_input
            )
            ch_value_outputs = ch_value_outputs.mix(MERLIN_MAGIC.out.value_results)
            ch_versions = ch_versions.mix(MERLIN_MAGIC.out.versions)
        }
    }

    // In the spirit of PHB, do a soft failure if reads did not pass or if assembly failed
    ch_failure_input = ch_failed_samples
        .map { meta, reads, screen_result_or_fail_type, fail_reason_or_type ->
            def fail_type = ""
            def fail_reason = ""
            def screen_result = ""
            
            if (screen_result_or_fail_type instanceof String) {
                fail_type = screen_result_or_fail_type
                fail_reason = fail_reason_or_type ?: "Unknown failure"
            } else {

                fail_type = fail_reason_or_type
                screen_result = screen_result_or_fail_type.text.trim()
                fail_reason = "Sample failed ${fail_type}: ${screen_result}"
            }
            
            [meta, fail_type, fail_reason]
        }

    CREATE_FAILURE_REPORT (
        ch_failure_input
    )
    ch_versions = ch_versions.mix(CREATE_FAILURE_REPORT.out.versions)
    
    ch_value_outputs = ch_value_outputs
        .groupTuple() // Group by sample ID to ensure unique entries
        .map { id, files -> tuple(id, files.flatten().unique()) } // Flatten and deduplicate files

    // Collect all value outputs for the JSON builder
    UTILITY_JSON_BUILDER (
        ch_value_outputs, file("$projectDir/modules/local/utilities/json_builder/json_builder.py")
    )

    emit:
    // Key outputs
    assembly = ch_assembly
    clean_reads = ch_clean_reads
    read_screen_raw = ch_read_screen_raw
    read_screen_clean = ch_read_screen_clean
    value_json = UTILITY_JSON_BUILDER.out.value_json_output
    
    // QUAST outputs
    quast_report = ch_quast_report
    
    // CG Pipeline outputs
    cg_pipeline_raw = ch_cg_pipeline_raw
    cg_pipeline_clean = ch_cg_pipeline_clean
    
    // BUSCO outputs
    busco_report = ch_busco_report
    busco_results = ch_busco_results
    
    // Failure reports
    failure_reports = CREATE_FAILURE_REPORT.out.failure_report
    
    // Versions
    versions = ch_versions
}