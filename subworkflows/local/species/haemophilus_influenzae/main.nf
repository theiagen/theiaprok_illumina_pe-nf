include { HICAP } from '../../../../modules/local/species_typing/haemophilus/hicap/main'

workflow HAEMOPHILUS_INFLUENZAE_SPECIES_TYPING {
    take:
    ch_assembly // channel: [ val(meta), path(assembly) ]

    main:

    HICAP (
        ch_assembly,
        params.hicap_min_gene_percent_coverage ?: 0.80,
        params.hicap_min_gene_depth ?: 10,
        params.hicap_min_gene_length ?: 100,
        params.hicap_min_gene_percent_identity ?: 90
    )

    emit:
    value_results = HICAP.out.hicap_value_results
    hicap_results = HICAP.out.hicap_results_tsv
    versions = HICAP.out.versions
}