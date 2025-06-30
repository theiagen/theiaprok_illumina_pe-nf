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
    
    // Initialize output channels
    ch_assembly = Channel.empty()
    ch_read_screen_raw = Channel.empty()
    ch_read_screen_clean = Channel.empty()
    ch_estimated_genome_length = Channel.empty()
    
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
            params.genome_length ?: ""
        )
        ch_read_screen_raw = RAW_CHECK_READS.out.read_screen
        ch_estimated_genome_length = RAW_CHECK_READS.out.est_genome_length
        ch_versions = ch_versions.mix(RAW_CHECK_READS.out.versions)
        
    ch_reads_to_process = ch_reads
        .join(ch_read_screen_raw)
        .filter { it[2].text.trim() == "PASS" }
        .map { [it[0], it[1]] }
    } else {
        ch_reads_to_process = ch_reads
    }
    
    // Only proceed if reads pass screening or screening is skipped
    ch_reads_to_process
        .ifEmpty { 
            log.warn "No samples passed raw read screening"
        }
        .set { ch_reads_for_qc }
    
    // Read QC and trimming
    READ_QC_TRIM_PE (
        ch_reads_for_qc,
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
            params.genome_length ?: ""
        )
        ch_read_screen_clean = CLEAN_CHECK_READS.out.read_screen
        ch_versions = ch_versions.mix(CLEAN_CHECK_READS.out.versions)
        
        ch_clean_reads_to_process = ch_clean_reads
            .join(ch_read_screen_clean)
            .filter { it[2].text.trim() == "PASS" }
            .map { [it[0], it[1]] }
    } else {
        ch_clean_reads_to_process = ch_clean_reads
    }
    
    // Only proceed with assembly if clean reads pass screening
    // I think this is the right way to hanlde it, but it could be improved
    ch_clean_reads_to_process
        .ifEmpty { 
            log.warn "No samples passed clean read screening"
        }
        .set { ch_reads_for_assembly }
    
    // If we have reads, we can proceed with assembly -- might want to add assembly failure handling later
    DIGGER_DENOVO (
        ch_reads_for_assembly
    )
    ch_assembly = DIGGER_DENOVO.out.assembly
    ch_versions = ch_versions.mix(DIGGER_DENOVO.out.versions)
    
    QUAST (
        ch_assembly
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)
    
    // Get genome length for coverage calculations
    ch_genome_length_for_cg = ch_assembly
        .join(QUAST.out.report)
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
        params.cg_pipe_opts ?: ""
    )
    ch_versions = ch_versions.mix(CG_PIPELINE_RAW.out.versions)
    
    ch_cg_clean_input = ch_clean_reads
        .join(ch_genome_length_for_cg, by: 0, remainder: true)
        .map { meta, reads, genome_length ->
            [meta, reads]
        }
    
    CG_PIPELINE_CLEAN (
        ch_cg_clean_input,
        params.genome_length ?: 3000000,
        params.cg_pipe_opts ?: ""
    )
    ch_versions = ch_versions.mix(CG_PIPELINE_CLEAN.out.versions)
    
    BUSCO (
        ch_assembly,
        false  // eukaryote = false for bacteria
    )
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    if (perform_characterization) {
        GAMBIT (
            ch_assembly,
            params.gambit_db_genomes,
            params.gambit_db_signatures
        )
        ch_versions = ch_versions.mix(GAMBIT.out.versions)
        
        // Get organism for downstream analysis
        ch_organism = ch_assembly
            .join(GAMBIT.out.predicted_taxon, by: 0, remainder: true)
            .map { meta, assembly, taxon ->
                def organism = params.expected_taxon ?: taxon ?: ""
                [meta, organism]
            }
        
        if (call_ani) {
            ANI_MUMMER (
                ch_assembly,
                params.ani_ref_genome ?: []
            )
            ch_versions = ch_versions.mix(ANI_MUMMER.out.versions)
        }
        
        if (call_kmerfinder) {
            KMERFINDER_BACTERIA (
                ch_assembly,
                params.kmerfinder_db ?: [],
            )
            ch_versions = ch_versions.mix(KMERFINDER_BACTERIA.out.versions)
        }
        
        ch_amrfinder_input = ch_assembly
            .join(ch_organism, by: 0)
        
        AMRFINDER_PLUS_NUC (
            ch_amrfinder_input.map { meta, assembly, organism -> [meta, assembly] },
            ch_amrfinder_input.map { meta, assembly, organism -> organism }
        )
        ch_versions = ch_versions.mix(AMRFINDER_PLUS_NUC.out.versions)
        
        if (call_resfinder) {
            RESFINDER (
                ch_amrfinder_input.map { meta, assembly, organism -> [meta, assembly] },
                params.resfinder_db_point ?: [],
                params.resfinder_db_res ?: []
            )
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
        ch_versions = ch_versions.mix(TS_MLST.out.versions)
        
        // Genome annotation
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
            ch_versions = ch_versions.mix(PLASMIDFINDER.out.versions)
        }
        
        if (call_abricate) {
            ABRICATE (
                ch_assembly,
                abricate_db,
                params.abricate_min_percent_identity ?: 80,
                params.abricate_min_percent_coverage ?: 80
            )
            ch_versions = ch_versions.mix(ABRICATE.out.versions)
        }
        
        ch_merlin_input = ch_assembly
            .join(ch_clean_reads, by: 0)
            .join(GAMBIT.out.merlin_tag, by: 0, remainder: true)
            .map { meta, assembly, reads, merlin_tag ->
                def tag = params.expected_taxon ?: merlin_tag ?: ""
                [meta, assembly, reads, tag]
            }
        
        MERLIN_MAGIC (
            ch_merlin_input.map { meta, assembly, reads, tag -> [meta, assembly, reads] },
            ch_merlin_input.map { meta, assembly, reads, tag -> tag }
        )
        ch_versions = ch_versions.mix(MERLIN_MAGIC.out.versions)
    }
    
    emit:
    // Key outputs
    assembly = ch_assembly
    clean_reads = ch_clean_reads
    read_screen_raw = ch_read_screen_raw
    read_screen_clean = ch_read_screen_clean
    
    // QUAST outputs
    quast_report = QUAST.out.report
    
    // CG Pipeline outputs
    cg_pipeline_raw = CG_PIPELINE_RAW.out.cg_pipeline_report
    cg_pipeline_clean = CG_PIPELINE_CLEAN.out.cg_pipeline_report
    
    // BUSCO outputs
    busco_report = BUSCO.out.busco_report
    busco_results = BUSCO.out.busco_results
    
    // Versions
    versions = ch_versions
}