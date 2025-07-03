include { LEGSTA } from '../../../../modules/local/species_typing/legionella/legsta/main'

workflow LEGIONELLA_PNEUMOPHILA_SPECIES_TYPING {

    take:
    ch_legionella // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_versions = Channel.empty()
    ch_legsta_results = Channel.empty()

    ch_assembly = ch_legionella.map { meta, assembly, reads, species -> [meta, assembly] }

    LEGSTA (
        ch_assembly
    )
    ch_legsta_results = LEGSTA.out.legsta_results
    ch_versions = ch_versions.mix(LEGSTA.out.versions)

    emit:
    legsta_results = ch_legsta_results
    
    versions = ch_versions
}