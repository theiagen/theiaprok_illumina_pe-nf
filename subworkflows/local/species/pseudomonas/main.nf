include { PASTY } from '../../../../modules/local/species_typing/pseudomonas/pasty/main'

workflow PSEUDOMONAS_AERUGINOSA_SPECIES_TYPING {

    take:
    ch_pseudomonas // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_versions = Channel.empty()
    ch_pasty_results = Channel.empty()
    ch_value_results = Channel.empty()

    ch_assembly = ch_pseudomonas.map { meta, assembly, reads, species -> [meta, assembly] }

    PASTY (
        ch_assembly
    )
    ch_value_results = ch_value_results.mix(PASTY.out.pasty_value_results)
    ch_pasty_results = PASTY.out.pasty_summary_tsv
    ch_versions = ch_versions.mix(PASTY.out.versions)

    emit:
    pasty_results = ch_pasty_results
    value_results = ch_value_results
    versions = ch_versions
}