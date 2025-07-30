include { NGMASTER } from '../../../../modules/local/species_typing/neisseria/ngmaster/main'

workflow NEISSERIA_GONORRHOEAE_TYPING {

    take:
    ch_ng_assembly

    main:
    ch_ngmaster_results = Channel.empty()
    ch_value_results = Channel.empty()
    ch_versions = Channel.empty()

    NGMASTER (ch_ng_assembly)
    ch_value_results = ch_value_results.mix(NGMASTER.out.ngmast_value_results)
    ch_ngmaster_results = NGMASTER.out.ngmast_report
    ch_versions = ch_versions.mix(NGMASTER.out.versions)

    emit:
    ngmast_report = ch_ngmaster_results
    value_results = ch_value_results
    versions = ch_versions
}