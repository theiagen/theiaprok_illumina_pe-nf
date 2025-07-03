include { EMMTYPER } from '../../../../modules/local/species_typing/streptococcus/emmtyper/main'
include { EMMTYPINGTOOL } from '../../../../modules/local/species_typing/streptococcus/emmtypingtool/main'

workflow STREPTOCOCCUS_PYOGENES_SPECIES_TYPING {
    take:
    ch_samples          // channel: [ val(meta), path(assembly), path(reads), val(species) ]

    main:

    ch_versions = Channel.empty()
    ch_emmtyper_results = Channel.empty()
    ch_emmtypingtool_results = Channel.empty()

    ch_samples_assembly = ch_samples.map { sample ->
        def (meta, assembly, reads, species) = sample
        [meta, assembly]
    }
    ch_samples_reads = ch_samples.map { sample ->
        def (meta, assembly, reads, species) = sample
        [meta, reads]
    }  

    EMMTYPER (
        ch_samples_assembly,
        params.emmtyper_wf ?: "blast",
        params.emmtyper_cluster_distance ?: 500,
        params.emmtyper_min_percent_identity ?: 95,
        params.emmtyper_culling_limit ?: 5,
        params.emmtyper_mismatch ?: 4,
        params.emmtyper_align_diff ?: 5,
        params.emmtyper_gap ?: 2,
        params.emmtyper_min_perfect ?: 15,
        params.emmtyper_min_good ?: 15,
        params.emmtyper_max_size ?: 2000
    )
    ch_emmtyper_results = EMMTYPER.out.emmtyper_results
    ch_versions = ch_versions.mix(EMMTYPER.out.versions)
    
    if (params.paired_end && !params.ont_data) {
        EMMTYPINGTOOL (
            ch_samples_reads
        )
        ch_emmtypingtool_results = EMMTYPINGTOOL.out.emmtypingtool_results
        ch_versions = ch_versions.mix(EMMTYPINGTOOL.out.versions)
    }

    emit:
    emmtyper_results = ch_emmtyper_results 
    emmtypingtool_results = ch_emmtypingtool_results 
    versions = ch_versions 
}