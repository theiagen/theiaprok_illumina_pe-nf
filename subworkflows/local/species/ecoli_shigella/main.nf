include { STXTYPER        } from '../../../../modules/local/species_typing/escherichia_shigella/stxtyper/main'
include { ECTYPER         } from '../../../../modules/local/species_typing/escherichia_shigella/ectyper/main'
include { SHIGATYPER      } from '../../../../modules/local/species_typing/escherichia_shigella/shigatyper/main'
include { SHIGEIFINDER    } from '../../../../modules/local/species_typing/escherichia_shigella/shigeifinder/main'
include { VIRULENCEFINDER } from '../../../../modules/local/species_typing/escherichia_shigella/virulencefinder/main'
include { SONNEITYPER     } from '../../../../modules/local/species_typing/escherichia_shigella/sonneityping/main'
include { SEROTYPEFINDER  } from '../../../../modules/local/species_typing/escherichia_shigella/serotypefinder/main'

workflow ESCHERICHIA_SHIGELLA_TYPING {

    take:
    ch_ecoli_shigella // Channel of tuples [meta, assembly, reads, species]


    main:

    ch_by_species = ch_ecoli_shigella.branch {
        ecoli_shigella: it[3] == "Escherichia" || it[3] == "Shigella sonnei" || it[3] == "Escherichia coli"
        sonnei_only: it[3] == "Shigella sonnei" && !params.assembly_only
        shiga_typer: it[3] == "Shigella sonnei" && !params.assembly_only && params.paired_end && !params.ont_data
    }

    ch_assembly = ch_by_species.ecoli_shigella.map { meta, assembly, reads, species ->
        [meta, assembly]
    }
    ch_sonneityper = ch_by_species.sonnei_only.map { meta, assembly, reads, species ->
        [meta, reads]
    }
    ch_shigatyper = ch_by_species.shiga_typer.map { meta, assembly, reads, species ->
        [meta, reads]
    }

    ch_versions = Channel.empty()
    ch_stxtyper_results = Channel.empty()
    ch_serotypefinder_results = Channel.empty()
    ch_ectyper_results = Channel.empty()
    ch_shigeifinder_results = Channel.empty()
    ch_virulencefinder_results = Channel.empty()
    ch_shigatyper_results = Channel.empty()
    ch_sonneityper_results = Channel.empty()
    ch_value_results = Channel.empty()

    // STX typer - special case: auto-run on Escherichia/Shigella, optional on others
    if (params.call_stxtyper) {
        STXTYPER (ch_assembly)
        ch_value_results = ch_value_results.mix(STXTYPER.out.stxtyper_value_results)
        ch_stxtyper_results = STXTYPER.out.stxtyper_report
        ch_versions = ch_versions.mix(STXTYPER.out.stxtyper_version)
    }

    SEROTYPEFINDER (
        ch_assembly
    )
    ch_value_results = ch_value_results.mix(SEROTYPEFINDER.out.serotypefinder_serotype)
    ch_serotypefinder_results = SEROTYPEFINDER.out.serotypefinder_report
    ch_versions = ch_versions.mix(SEROTYPEFINDER.out.versions)
        
    ECTYPER (
        ch_assembly,
        params.ectyper_o_min_percent_identity ?: 90,
        params.ectyper_h_min_percent_identity ?: 95,
        params.ectyper_o_min_percent_coverage ?: 90,
        params.ectyper_h_min_percent_coverage ?: 50,
        params.ectyper_verify ?: false,
        params.ectyper_print_alleles ?: false
    )
    ch_value_results = ch_value_results.mix(ECTYPER.out.ectyper_predicted_serotype_file)
    ch_ectyper_results = ECTYPER.out.ectyper_results
    ch_versions = ch_versions.mix(ECTYPER.out.versions)

    SHIGEIFINDER (
        ch_assembly
    )
    ch_value_results = ch_value_results.mix(SHIGEIFINDER.out.shigeifinder_value_results)
    ch_shigeifinder_results = SHIGEIFINDER.out.shigeifinder_report
    ch_versions = ch_versions.mix(SHIGEIFINDER.out.versions)

    VIRULENCEFINDER (
        ch_assembly,
        params.virulencefinder_database ?: "virulence_ecoli",
        params.virulencefinder_min_percent_coverage ?: 0.60,
        params.virulencefinder_min_percent_identity ?: 0.80
    )
    ch_value_results = ch_value_results.mix(VIRULENCEFINDER.out.virulence_factors)
    ch_virulencefinder_results = VIRULENCEFINDER.out.virulence_report
    ch_versions = ch_versions.mix(VIRULENCEFINDER.out.versions)

    SHIGATYPER (ch_shigatyper,params.ont_data ?: false)
    ch_value_results = ch_value_results.mix(SHIGATYPER.out.shigatyper_value_results)
    ch_shigatyper_results = SHIGATYPER.out.shigatyper_summary
    ch_versions = ch_versions.mix(SHIGATYPER.out.versions)

    SONNEITYPER (
        ch_sonneityper,
        params.ont_data ?: false
    )
    ch_value_results = ch_value_results.mix(SONNEITYPER.out.sonneityping_value_results)
    ch_sonneityper_results = SONNEITYPER.out.sonneityping_final_report
    ch_versions = ch_versions.mix(SONNEITYPER.out.versions)

    emit:
    stxtyper_results = ch_stxtyper_results
    serotypefinder_results = ch_serotypefinder_results
    ectyper_results = ch_ectyper_results
    shigeifinder_results = ch_shigeifinder_results
    virulencefinder_results = ch_virulencefinder_results
    shigatyper_results = ch_shigatyper_results
    sonneityper_results = ch_sonneityper_results
    value_results = ch_value_results
    versions = ch_versions
}
