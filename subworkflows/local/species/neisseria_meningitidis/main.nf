include { MENINGOTYPE } from '../../../../modules/local/species_typing/neisseria/meningotype/main'

workflow NEISSERIA_MENINGITIDIS_TYPING {

    take:
    ch_input

    main:
    ch_ngmaster_results = Channel.empty()
    ch_versions = Channel.empty()

    ch_assembly = ch_input.map { meta, assembly, reads, species -> [meta, assembly] }

    MENINGOTYPE (ch_assembly)
    ch_ngmaster_results = MENINGOTYPE.out.meningotype_report
    ch_versions = ch_versions.mix(MENINGOTYPE.out.versions)

    emit:
    meningotype_report = ch_ngmaster_results
    versions = ch_versions
}