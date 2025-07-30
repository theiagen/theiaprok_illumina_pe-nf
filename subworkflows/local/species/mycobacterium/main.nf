include { CLOCKWORK_DECON_READS } from '../../../../modules/local/species_typing/mycobacterium/clockwork/main'
include { TBPROFILER            } from '../../../../modules/local/species_typing/mycobacterium/tbprofiler/main'
include { TBP_PARSER            } from '../../../../modules/local/species_typing/mycobacterium/tbp_parser/main'

workflow MYCOBACTERIUM_TUBERCULOSIS_SPECIES_TYPING {

    take:
    ch_mycobacterium // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_versions = Channel.empty()
    ch_clockwork_results = Channel.empty()
    ch_tbprofiler_results = Channel.empty()
    ch_tbp_parser_results = Channel.empty()
    ch_value_results = Channel.empty()


    // Extract reads for analysis
    ch_reads = ch_mycobacterium.map { meta, assembly, reads, species -> [meta, reads] }

    // Clockwork decontamination for paired-end, non-ONT data
    if (params.paired_end && !params.ont_data) {
        CLOCKWORK_DECON_READS (
            ch_reads
        )
        ch_clockwork_results = CLOCKWORK_DECON_READS.out.cleaned_reads
        ch_versions = ch_versions.mix(CLOCKWORK_DECON_READS.out.versions)
        
        // Use cleaned reads for downstream analysis
        ch_tb_reads = CLOCKWORK_DECON_READS.out.cleaned_reads
    } else {
        ch_tb_reads = ch_reads
    }
    
    TBPROFILER (
        ch_tb_reads,
        params.ont_data ?: false // Set to true if ONT data is used, ie. used in TheiaProk-ONT
    )
    ch_value_results = ch_value_results.mix(TBPROFILER.out.tbprofiler_value_results)
    ch_tbprofiler_results = TBPROFILER.out.tbparser_inputs
    ch_versions = ch_versions.mix(TBPROFILER.out.versions)

    TBP_PARSER (
        ch_tbprofiler_results,
        params.tbp_parser_config ?: "", // YAML config file for TBP_Parser
        params.tbp_parser_sequencing_method ?: "", // Fills out seq_method in TBP_Parser output
        params.tbp_parser_operator ?: "",
        params.tbp_parser_min_depth ?: 10,
        params.tbp_parser_min_frequency ?: 0.1,
        params.tbp_parser_min_read_support ?: 10,
        params.tbp_parser_min_percent_coverage ?: 100,
        params.tbp_parser_coverage_regions_bed ?: "",
        params.tbp_parser_add_cycloserine_lims ?: false,
        params.tbp_parser_debug ?: true,
        params.tbp_parser_tngs ?: false,
        params.tbp_parser_rrs_frequncy ?: 0.1,
        params.tbp_parser_rrs_read_support ?: 10,
        params.tbp_parser_rr1_frequency ?: 0.1,
        params.tbp_parser_rr1_read_support ?: 10,
        params.tbp_parser_rpob499_frequency ?: 0.1,
        params.tbp_parser_etha237_frequency ?: 0.1,
        params.tbp_parser_expert_rule_regions_bed ?: ""
    )
    ch_value_results = ch_value_results.mix(TBP_PARSER.out.tbp_parser_value_results)
    ch_tbp_parser_results = TBP_PARSER.out.looker_report
    ch_versions = ch_versions.mix(TBP_PARSER.out.versions)

    emit:
    clockwork_results = ch_clockwork_results
    tbprofiler_results = ch_tbprofiler_results
    tbp_parser_results = ch_tbp_parser_results
    value_results = ch_value_results
    versions = ch_versions
}