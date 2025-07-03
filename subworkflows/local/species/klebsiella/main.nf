include { KLEBORATE } from '../../../../modules/local/species_typing/klebsiella/kleborate/main'

workflow KLEBSIELLA_TYPING {

    take:
    ch_klebsiella // Channel of tuples [meta, assembly]

    main:
    ch_versions = Channel.empty()
    ch_kleborate_results = Channel.empty()

    KLEBORATE (ch_klebsiella)
    ch_kleborate_results = KLEBORATE.out.kleborate_report
    ch_versions = ch_versions.mix(KLEBORATE.out.versions)

    emit:
    kleborate_results = ch_kleborate_results
    versions = ch_versions
}