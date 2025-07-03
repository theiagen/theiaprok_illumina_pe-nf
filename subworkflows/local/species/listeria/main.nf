include { LISSERO  } from '../../../../modules/local/species_typing/listeria/lissero/main'
workflow LISTERIA_SPECIES_TYPING {

    take:
    ch_listeria // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_samples = ch_listeria.map { meta, assembly, reads, species -> [meta, assembly] }

    ch_versions = Channel.empty()
    ch_lissero_results = Channel.empty()

    LISSERO (
        ch_samples,
        params.lissero_min_percent_identity ?: 95.0,
        params.lissero_min_percent_coverage ?: 95.0
    )
    ch_lissero_results = LISSERO.out.lissero_results
    ch_versions = ch_versions.mix(LISSERO.out.versions)


    emit:
    lissero_results = ch_lissero_results

    versions = ch_versions
}