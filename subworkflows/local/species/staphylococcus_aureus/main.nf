include { SPATYPER         } from '../../../../modules/local/species_typing/staphylococcus/spatyper/main'
include { STAPHOPIASCCMEC } from '../../../../modules/local/species_typing/staphylococcus/staphopiasccmec/main'
include { AGRVATE         } from '../../../../modules/local/species_typing/staphylococcus/agrvate/main'

workflow STAPHYLOCOCCUS_AUREUS_SPECIES_TYPING {

    take:
    ch_staphylococcus // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_versions = Channel.empty()
    ch_spatyper_results = Channel.empty()
    ch_staphopiasccmec_results = Channel.empty()
    ch_agrvate_results = Channel.empty()

    // Extract assembly for all tools
    ch_assembly = ch_staphylococcus.map { meta, assembly, reads, species -> [meta, assembly] }

    SPATYPER (
        ch_assembly,
        params.spatyper_do_enrich ?: false
    )
    ch_spatyper_results = SPATYPER.out.tsv
    ch_versions = ch_versions.mix(SPATYPER.out.versions)
    
    STAPHOPIASCCMEC (
        ch_assembly
    )
    ch_staphopiasccmec_results = STAPHOPIASCCMEC.out.staphopia_results_tsv
    ch_versions = ch_versions.mix(STAPHOPIASCCMEC.out.versions)
    
    AGRVATE (
        ch_assembly
    )
    ch_agrvate_results = AGRVATE.out.agrvate_summary
    ch_versions = ch_versions.mix(AGRVATE.out.versions)

    emit:
    spatyper_results = ch_spatyper_results
    staphopiasccmec_results = ch_staphopiasccmec_results
    agrvate_results = ch_agrvate_results
    
    versions = ch_versions
}