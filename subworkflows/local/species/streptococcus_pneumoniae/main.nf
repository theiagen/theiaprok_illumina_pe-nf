include { SEROBA           } from '../../../../modules/local/species_typing/streptococcus/seroba/main'
include { PBPTYPER         } from '../../../../modules/local/species_typing/streptococcus/pbptyper/main'
include { POPPUNK_DATABASE } from '../../../../modules/local/species_typing/streptococcus/poppunk/fetch/main'
include { POPPUNK          } from '../../../../modules/local/species_typing/streptococcus/poppunk/run/main'

workflow STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING {

    take:
    ch_streptococcus // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_versions = Channel.empty()
    ch_pbptyper_results = Channel.empty()
    ch_value_results = Channel.empty()

    // Extract reads and assembly
    ch_reads = ch_streptococcus.map { meta, assembly, reads, species -> [meta, reads] }
    ch_assembly = ch_streptococcus.map { meta, assembly, reads, species -> [meta, assembly] }

    if (params.paired_end && !params.ont_data) {
        SEROBA (
            ch_reads
        )
        ch_value_results = ch_value_results.mix(SEROBA.out.seroba_value_results)
        ch_versions = ch_versions.mix(SEROBA.out.versions)
    }
    
    PBPTYPER (
        ch_assembly,
        params.pbptyper_database ?: [],  // database - empty for default - can change
        params.pbptyper_min_percent_identity ?: 95,
        params.pbptyper_min_percent_coverage ?: 95
    )
    ch_pbptyper_results = PBPTYPER.out.pbtyper_predicted_tsv
    ch_versions = ch_versions.mix(PBPTYPER.out.versions)
    
    if (params.call_poppunk) {
        // Fetch PopPUNK GPS database
        POPPUNK_DATABASE (
            params.poppunk_gps_db_url ?: "https://gps-project.cog.sanger.ac.uk/GPS_6.tar.gz",
            params.poppunk_gps_external_clusters_url ?: "https://gps-project.cog.sanger.ac.uk/GPS_v6_external_clusters.csv"
        )
        ch_versions = ch_versions.mix(POPPUNK_DATABASE.out.versions)
        
        // Run PopPUNK with fetched database
        POPPUNK (
            ch_assembly,
            POPPUNK_DATABASE.out.database,
            POPPUNK_DATABASE.out.ext_clusters,
            POPPUNK_DATABASE.out.db_info
        )
        ch_value_results = ch_value_results.mix(POPPUNK.out.poppunk_value_results)
        ch_versions = ch_versions.mix(POPPUNK.out.versions)
    }

    emit:
    pbtyper_results = ch_pbptyper_results
    value_results = ch_value_results
    versions = ch_versions
}