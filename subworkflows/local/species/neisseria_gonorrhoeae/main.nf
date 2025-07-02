include { NGMASTER } from '../../../../modules/local/species_typing/neisseria/ngmaster/main'

workflow NEISSERIA_GONORRHOEAE_TYPING {

    take:
    ch_ng_assembly

    main:
    ch_ngmaster_results = Channel.empty()
    ch_versions = Channel.empty()

    NGMASTER (ch_ng_assembly)
    ch_ngmaster_results = NGMASTER.out.ngmast_report
    ch_versions = ch_versions.mix(NGMASTER.out.versions)

    emit:
    ngmast_report = ch_ngmaster_results
    versions = ch_versions
}