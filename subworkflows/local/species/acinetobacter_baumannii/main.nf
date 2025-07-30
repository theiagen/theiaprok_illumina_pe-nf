include { KAPTIVE  } from '../../../../modules/local/species_typing/acinobacter/kaptive/main'
include { ABRICATE } from '../../../../modules/local/gene_typing/drug_resistance/abricate/main'
workflow ACINETOBACTER_SPECIES_TYPING {

    take:
    ch_acinetobacter // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_samples = ch_acinetobacter.map { meta, assembly, reads, species -> [meta, assembly] }

    ch_versions = Channel.empty()
    ch_value_results = Channel.empty()

    KAPTIVE (
        ch_samples,
        params.kaptive_start_end_margin ?: 10,
        params.kaptive_min_percent_coverage ?: 90.0,
        params.kaptive_min_percent_identity ?: 80.0,
        params.kaptive_low_gene_percent_identity ?: 95.0
    )
    ch_value_results = ch_value_results.mix(KAPTIVE.out.kaptive_value_results)
    ch_versions = ch_versions.mix(KAPTIVE.out.versions)

    ABRICATE (
        ch_samples,
        "AcinetobacterPlasmidTyping",
        params.abricate_abaum_min_percent_identity ?: 95,
        params.abricate_abaum_min_percent_coverage ?: 90
    )
    ch_value_results = ch_value_results.mix(ABRICATE.out.genes_file)
    ch_versions = ch_versions.mix(ABRICATE.out.versions)

    emit:
    value_results = ch_value_results
    versions = ch_versions
}