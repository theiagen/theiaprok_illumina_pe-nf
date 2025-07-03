include { FASTQ_SCAN_PE as FASTQ_SCAN_PE_RAW }         from '../../../../modules/local/quality_control/basic_statistics/fastq_scan/main'
include { FASTQ_SCAN_PE as FASTQ_SCAN_PE_CLEAN }         from '../../../../modules/local/quality_control/basic_statistics/fastq_scan/main'
include { FASTQC as FASTQC_RAW }              from '../../../../modules/local/quality_control/basic_statistics/fastqc/main'
include { FASTQC as FASTQC_CLEAN }              from '../../../../modules/local/quality_control/basic_statistics/fastqc/main'
include { READLENGTH }          from '../../../../modules/local/quality_control/basic_statistics/readlength/main'
include { BBDUK }               from '../../../../modules/local/quality_control/read_filtering/bbduk/main'
include { FASTP_PE }            from '../../../../modules/local/quality_control/read_filtering/fastp_pe/main'
include { NCBI_SCRUB_PE }       from '../../../../modules/local/quality_control/read_filtering/ncbi_scrub/main'
include { TRIMMOMATIC_PE }      from '../../../../modules/local/quality_control/read_filtering/trimmomatic/main'
include { KRAKEN2 }  from '../../../../modules/local/taxon_id/contamination/kraken2/main'
include { MIDAS }               from '../../../../modules/local/taxon_id/contamination/midas/run/main'

workflow READ_QC_TRIM_PE {
    // Keep path selected for theiaprok for first pass
    take:
    reads                    // channel: [ val(meta), path(read1), path(read2) ]
    trim_min_length          // val: minimum read length after trimming
    trim_quality_min_score   // val: minimum quality score for trimming
    trim_window_size         // val: window size for quality trimming
    call_midas               // val: boolean to call midas
    midas_db                 // path: midas database
    call_kraken              // val: boolean to call kraken
    kraken_db                // path: kraken database
    adapters                 // path: adapter sequences
    phix                     // path: phix sequences
    workflow_series          // val: workflow series (theiacov, theiaprok, etc.)
    read_processing          // val: read processing method (trimmomatic, fastp)
    read_qc                  // val: read qc method (fastq_scan, fastqc)
    trimmomatic_args         // val: trimmomatic arguments
    fastp_args               // val: fastp arguments

    main:
    ch_versions = Channel.empty()
    
    // Not sure if this is the best way to handle these channels, but it works for now
    // Just trying to map the outputs to the expected channels like we do in the wdl version
    ch_trimmed_reads = Channel.empty()
    ch_fastq_scan_raw_r1 = Channel.empty()
    ch_fastq_scan_raw_r2 = Channel.empty()
    ch_fastq_scan_raw_pairs = Channel.empty()
    ch_fastq_scan_raw_json1 = Channel.empty()
    ch_fastq_scan_raw_json2 = Channel.empty()
    ch_fastq_scan_clean_r1 = Channel.empty()
    ch_fastq_scan_clean_r2 = Channel.empty()
    ch_fastq_scan_clean_pairs = Channel.empty()
    ch_fastq_scan_clean_json1 = Channel.empty()
    ch_fastq_scan_clean_json2 = Channel.empty()
    ch_fastqc_raw_read1_html = Channel.empty()
    ch_fastqc_raw_read2_html = Channel.empty()
    ch_fastqc_clean_html1 = Channel.empty()
    ch_fastqc_clean_html2 = Channel.empty()
    ch_fastqc_clean_zip1 = Channel.empty()
    ch_fastqc_clean_zip2 = Channel.empty()
    ch_trimmomatic_stats = Channel.empty()
    ch_fastp_pe_html_report = Channel.empty()
    ch_midas_species_profile = Channel.empty()
    ch_kraken2_report = Channel.empty()
    ch_value_results = Channel.empty()

    // Read processing - trimmomatic or fastp
    if (read_processing == "trimmomatic") {
        TRIMMOMATIC_PE(
            reads,
            trim_min_length,
            trim_window_size,
            trim_quality_min_score,
            "", // base_crop - empty for no cropping
            trimmomatic_args ?: "-phred33"
        )
        ch_trimmed_reads = TRIMMOMATIC_PE.out.trimmed_reads
        ch_trimmomatic_stats = TRIMMOMATIC_PE.out.trimmomatic_stats
        ch_versions = ch_versions.mix(TRIMMOMATIC_PE.out.versions)
    }

    if (read_processing == "fastp") {
        FASTP_PE(
            reads,
            trim_window_size,
            trim_quality_min_score,
            trim_min_length,
            fastp_args ?: "--detect_adapter_for_pe -g -5 20 -3 20"
        )
        ch_trimmed_reads = FASTP_PE.out.trimmed_reads
        ch_fastp_pe_html_report = FASTP_PE.out.fastp_stats
        ch_versions = ch_versions.mix(FASTP_PE.out.versions)
    }

    // BBDuk cleaning
    BBDUK(
        ch_trimmed_reads,
        adapters ?: [],
        phix ?: []
    )
    ch_versions = ch_versions.mix(BBDUK.out.versions)

    ch_clean_reads = BBDUK.out.cleaned_reads

    // Quality control - fastqc or fastq_scan
    if (read_qc == "fastqc") {
        // FastQC on raw reads
        FASTQC_RAW (reads, "raw")
        ch_value_results = ch_value_results.mix(FASTQC_RAW.out.fastqc_value_results)
        ch_versions = ch_versions.mix(FASTQC_RAW.out.versions)
        ch_fastqc_raw_read1_html = FASTQC_RAW.out.read1_fastqc_html
        ch_fastqc_raw_read2_html = FASTQC_RAW.out.read2_fastqc_html

        // FastQC on clean reads
        FASTQC_CLEAN (ch_clean_reads, "clean")
        ch_value_results = ch_value_results.mix(FASTQC_CLEAN.out.fastqc_value_results)
        ch_fastqc_clean_html1 = FASTQC_CLEAN.out.read1_fastqc_html
        ch_fastqc_clean_html2 = FASTQC_CLEAN.out.read2_fastqc_html
        ch_fastqc_clean_zip1 = FASTQC_CLEAN.out.read1_fastqc_zip
        ch_fastqc_clean_zip2 = FASTQC_CLEAN.out.read2_fastqc_zip
        ch_versions = ch_versions.mix(FASTQC_CLEAN.out.versions)

    }

    if (read_qc == "fastq_scan") {
        // FastQ-scan on raw reads
        FASTQ_SCAN_PE_RAW (reads, "raw")
        ch_value_results = ch_value_results.mix(FASTQ_SCAN_PE_RAW.out.fastq_scan_value_results)
        ch_fastq_scan_raw_json1 = FASTQ_SCAN_PE_RAW.out.read1_fastq_scan_json
        ch_fastq_scan_raw_json2 = FASTQ_SCAN_PE_RAW.out.read2_fastq_scan_json
        ch_versions = ch_versions.mix(FASTQ_SCAN_PE_RAW.out.versions)

        // FastQ-scan on clean reads
        FASTQ_SCAN_PE_CLEAN (ch_clean_reads, "clean")
        ch_value_results = ch_value_results.mix(FASTQ_SCAN_PE_CLEAN.out.fastq_scan_value_results)
        ch_fastq_scan_clean_json1 = FASTQ_SCAN_PE_CLEAN.out.read1_fastq_scan_json
        ch_fastq_scan_clean_json2 = FASTQ_SCAN_PE_CLEAN.out.read2_fastq_scan_json
        ch_versions = ch_versions.mix(FASTQ_SCAN_PE_CLEAN.out.versions)
    }

    // MIDAS for theiaprok
    if (workflow_series == "theiaprok" && call_midas) {
        MIDAS(
            reads,
            midas_db
        )
        ch_midas_species_profile = MIDAS.out.species_profile
        ch_midas_log_file = MIDAS.out.log_file
        ch_value_results = ch_value_results.mix(MIDAS.out.midas_value_results)
        ch_versions = ch_versions.mix(MIDAS.out.versions)
    }

    // Kraken2 standalone for theiaprok
    if (workflow_series == "theiaprok" && call_kraken && kraken_db) {
        KRAKEN2(
            reads,
            kraken_db,
            "", // kraken2_args
            "classified#.fastq", // classified_out
            "unclassified#.fastq" // unclassified_out
        )
        ch_value_results = ch_value_results.mix(KRAKEN2.out.kraken2_percent_human_file)
        ch_kraken2_report = KRAKEN2.out.kraken2_report
        ch_versions = ch_versions.mix(KRAKEN2.out.versions)
    }

    
    emit:
    // BBDuk outputs
    bbduk_cleaned_reads       = BBDUK.out.cleaned_reads
    bbduk_adapters_stats      = BBDUK.out.adapter_stats
    bbduk_phix_stats          = BBDUK.out.phix_stats
    // FastQ-scan outputs
    fastq_scan_raw_r1        = ch_fastq_scan_raw_r1
    fastq_scan_raw_r2        = ch_fastq_scan_raw_r2
    fastq_scan_raw_pairs     = ch_fastq_scan_raw_pairs
    fastq_scan_clean_r1      = ch_fastq_scan_clean_r1
    fastq_scan_clean_r2      = ch_fastq_scan_clean_r2
    fastq_scan_clean_pairs   = ch_fastq_scan_clean_pairs
    fastq_scan_raw_json1     = ch_fastq_scan_raw_json1
    fastq_scan_raw_json2     = ch_fastq_scan_raw_json2
    fastq_scan_clean_json1   = ch_fastq_scan_clean_json1
    fastq_scan_clean_json2   = ch_fastq_scan_clean_json2
    // FastQC outputs
    fastqc_raw_html1         = ch_fastqc_raw_read1_html
    fastqc_raw_html2         = ch_fastqc_raw_read2_html
    fastqc_clean_html1       = ch_fastqc_clean_html1
    fastqc_clean_html2       = ch_fastqc_clean_html2
    fastqc_clean_zip1        = ch_fastqc_clean_zip1
    fastqc_clean_zip2        = ch_fastqc_clean_zip2
    // Kraken2 outputs
    kraken2_report           = ch_kraken2_report
    // Trimming outputs
    trimmomatic_stats        = ch_trimmomatic_stats
    fastp_html_report        = ch_fastp_pe_html_report
    // MIDAS outputs
    midas_species_profile    = ch_midas_species_profile
    // Versions
    versions                 = ch_versions
}