include { SRST2_VIBRIO } from '../../../../modules/local/species_typing/vibrio/srst2/main'
include { VIBECHECK_VIBRIO } from '../../../../modules/local/species_typing/vibrio/vibecheck_vibrio/main'
include { ABRICATE_VIBRIO } from '../../../../modules/local/species_typing/vibrio/abricate_vibrio/main'

workflow VIBRIO_SPECIES_TYPING {
    take:
    ch_samples // channel: [ val(meta), path(assembly), path(reads), val(species) ]

    main:

    ch_reads = ch_samples.map { meta, assembly, reads, species -> [meta, reads] }
    ch_assembly = ch_samples.map { meta, assembly, reads, species -> [meta, assembly] }

    ch_versions = Channel.empty()
    
    // Initialize empty channels for optional outputs
    ch_srst2_vibrio_results = Channel.empty()
    ch_vibecheck_results = Channel.empty()

    if (!params.assembly_only && !params.ont_data) {
        SRST2_VIBRIO (
            ch_reads,
            params.srst2_min_percent_coverage ?: 80,
            params.srst2_max_divergence ?: 20,
            params.srst2_min_depth ?: 5,
            params.srst2_min_edge_depth ?: 2,
            params.srst2_gene_max_mismatch ?: 2000
        )
        ch_srst2_vibrio_results = SRST2_VIBRIO.out.srst2_detailed_tsv
        ch_versions = ch_versions.mix(SRST2_VIBRIO.out.versions)
        
        // VibeCheck for O1 serogroup
        if (params.paired_end) {
            ch_o1_reads = ch_reads
                .join(SRST2_VIBRIO.out.srst2_serogroup)
                .filter { meta, reads, srst2_serogroup -> 
                    def serogroup_content = srst2_serogroup.text.trim()
                    serogroup_content == "O1" 
                }
                .map { meta, reads, srst2_serogroup -> [meta, reads] }

            VIBECHECK_VIBRIO (
                ch_o1_reads,
                params.vibecheck_vibrio_barcodes ?: [] // lineage_barcodes - would need to be provided
            )
            ch_vibecheck_results = VIBECHECK_VIBRIO.out.report
            ch_versions = ch_versions.mix(VIBECHECK_VIBRIO.out.versions)
        }
    }

    // Abricate for Vibrio path
    ABRICATE_VIBRIO (
        ch_assembly,
        "vibrio",  // Vibrio database string
        params.abricate_vibrio_min_percent_identity ?: 80,
        params.abricate_vibrio_min_percent_coverage ?: 80
    )
    ch_versions = ch_versions.mix(ABRICATE_VIBRIO.out.versions)

    emit:
    srst2_vibrio_results = ch_srst2_vibrio_results
    vibecheck_results = ch_vibecheck_results
    abricate_results = ABRICATE_VIBRIO.out.abricate_hits
    versions = ch_versions
}