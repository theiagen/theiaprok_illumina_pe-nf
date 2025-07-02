include { ABRICATE                     } from '../../../../modules/local/gene_typing/drug_resistance/abricate/main'
include { AMR_SEARCH                   } from '../../../../modules/local/gene_typing/drug_resistance/amr_search/main'
include { KAPTIVE                      } from '../../../../modules/local/species_typing/acinobacter/kaptive/main'
include { SEROTYPEFINDER               } from '../../../../modules/local/species_typing/escherichia_shigella/serotypefinder/main'
include { SHIGEIFINDER                 } from '../../../../modules/local/species_typing/escherichia_shigella/shigeifinder/main'
include { SHIGATYPER                   } from '../../../../modules/local/species_typing/escherichia_shigella/shigatyper/main'
include { SONNEITYPER                  } from '../../../../modules/local/species_typing/escherichia_shigella/sonneityping/main'
include { STXTYPER                     } from '../../../../modules/local/species_typing/escherichia_shigella/stxtyper/main'
include { VIRULENCEFINDER              } from '../../../../modules/local/species_typing/escherichia_shigella/virulencefinder/main'
include { ECTYPER                      } from '../../../../modules/local/species_typing/escherichia_shigella/ectyper/main'
include { HICAP                        } from '../../../../modules/local/species_typing/haemophilus/hicap/main'
include { KLEBORATE                    } from '../../../../modules/local/species_typing/klebsiella/kleborate/main'
include { LEGSTA                       } from '../../../../modules/local/species_typing/legionella/legsta/main'
include { CLOCKWORK_DECON_READS        } from '../../../../modules/local/species_typing/mycobacterium/clockwork/main'
include { TBPROFILER                   } from '../../../../modules/local/species_typing/mycobacterium/tbprofiler/main'
include { TBP_PARSER                   } from '../../../../modules/local/species_typing/mycobacterium/tbp_parser/main'
include { MENINGOTYPE                  } from '../../../../modules/local/species_typing/neisseria/meningotype/main'
include { NGMASTER                     } from '../../../../modules/local/species_typing/neisseria/ngmaster/main'
include { PASTY                        } from '../../../../modules/local/species_typing/pseudomonas/pasty/main'
include { GENOTYPHI                    } from '../../../../modules/local/species_typing/salmonella/genotyphi/main'
include { SEQSERO2                     } from '../../../../modules/local/species_typing/salmonella/seqsero2/main'
include { SISTR                        } from '../../../../modules/local/species_typing/salmonella/sistr/main'
include { AGRVATE                      } from '../../../../modules/local/species_typing/staphylococcus/agrvate/main'
include { SPATYPER                     } from '../../../../modules/local/species_typing/staphylococcus/spatyper/main'
include { STAPHOPIASCCMEC              } from '../../../../modules/local/species_typing/staphylococcus/staphopiasccmec/main'
include { EMMTYPER                     } from '../../../../modules/local/species_typing/streptococcus/emmtyper/main'
include { EMMTYPINGTOOL                } from '../../../../modules/local/species_typing/streptococcus/emmtypingtool/main'
include { PBPTYPER                     } from '../../../../modules/local/species_typing/streptococcus/pbptyper/main'
include { POPPUNK_DATABASE             } from '../../../../modules/local/species_typing/streptococcus/poppunk/fetch/main'
include { POPPUNK                      } from '../../../../modules/local/species_typing/streptococcus/poppunk/run/main'
include { SEROBA                       } from '../../../../modules/local/species_typing/streptococcus/seroba/main'
include { SRST2_VIBRIO                 } from '../../../../modules/local/species_typing/vibrio/srst2/main'
include { VIBECHECK_VIBRIO             } from '../../../../modules/local/species_typing/vibrio/vibecheck_vibrio/main'
include { TS_MLST                      } from '../../../../modules/local/species_typing/multi/ts_mlst/main'

// New Subworkflows 
include { ACINETOBACTER_SPECIES_TYPING } from '../../../local/species/acinetobacter_baumannii/main'
include { LISTERIA_SPECIES_TYPING } from '../../../local/species/listeria/main'
include { SALMONELLA_SPECIES_TYPING } from '../../../local/species/salmonella/main'
include { ESCHERICHIA_SHIGELLA_TYPING } from '../../../local/species/ecoli_shigella/main'

workflow MERLIN_MAGIC {
    
    take:
    ch_samples          // channel: [ val(meta), path(assembly), path(reads), val(species) ]
    
    main:
    
    ch_samples_by_species = ch_samples.branch {
        acinetobacter: it[3] == "Acinetobacter baumannii" || 
                       it[3] == "Acinetobacter" || 
                       it[3] == "Acinetobacter spp."
        listeria:      it[3] == "Listeria"
        salmonella:    it[3] == "Salmonella"
        ecoli_shigella: it[3] == "Escherichia" || 
                        it[3] == "Shigella sonnei" || 
                        it[3] == "Escherichia coli"
    }

    ACINETOBACTER_SPECIES_TYPING(ch_samples_by_species.acinetobacter)

    if (!ch_samples_by_species.listeria.isEmpty()) {
        // If not empty, run the LISTERIA_SPECIES_TYPING subworkflow
        LISTERIA_SPECIES_TYPING(ch_samples_by_species.listeria)
    }

    if (!ch_samples_by_species.salmonella.isEmpty()) {
        // If not empty, run the Salmonella species typing subworkflow
        SALMONELLA_SPECIES_TYPING(ch_samples_by_species.salmonella)
    }
    
    if (!ch_samples_by_species.ecoli_shigella.isEmpty()) {
        // If not empty, run the Escherichia/Shigella species typing subworkflow
        ESCHERICHIA_SHIGELLA_TYPING(ch_samples_by_species.ecoli_shigella)
    }
    
    // Klebsiella species typing
    if (merlin_tag in ["Klebsiella", "Klebsiella pneumoniae", "Klebsiella variicola", "Klebsiella aerogenes", "Klebsiella oxytoca"]) {
        KLEBORATE (
            ch_assembly
        )
        ch_kleborate_results = KLEBORATE.out.kleborate_report
        ch_versions = ch_versions.mix(KLEBORATE.out.versions)
    }
    
    // Neisseria gonorrhoeae typing
    if (merlin_tag == "Neisseria gonorrhoeae") {
        NGMASTER (
            ch_assembly
        )
        ch_ngmaster_results = NGMASTER.out.ngmast_report
        ch_versions = ch_versions.mix(NGMASTER.out.versions)
    }
    
    // Neisseria meningitidis typing
    if (merlin_tag == "Neisseria meningitidis") {
        MENINGOTYPE (
            ch_assembly
        )
        ch_meningotype_results = MENINGOTYPE.out.meningotype_report
        ch_versions = ch_versions.mix(MENINGOTYPE.out.versions)
    }
    
    // Pseudomonas aeruginosa typing
    if (merlin_tag == "Pseudomonas aeruginosa") {
        PASTY (
            ch_assembly
        )
        ch_pasty_results = PASTY.out.pasty_summary_tsv
        ch_versions = ch_versions.mix(PASTY.out.versions)
    }
    
    // Mycobacterium tuberculosis typing
    if (merlin_tag == "Mycobacterium tuberculosis" && !params.assembly_only) {
        // Clockwork decontamination for paired-end, non-ONT data
        if (params.paired_end && !params.ont_data) {
            CLOCKWORK_DECON_READS (
                ch_reads
            )
            ch_clockwork_results = CLOCKWORK_DECON_READS.out.cleaned_reads
            ch_versions = ch_versions.mix(CLOCKWORK_DECON_READS.out.versions)
            
            // Use cleaned reads for downstream analysis
            ch_tb_reads = CLOCKWORK_DECON_READS.out.cleaned_reads
        } else {
            ch_tb_reads = ch_reads
        }
        
        TBPROFILER (
            ch_tb_reads,
            params.ont_data ?: false, // Set to true if ONT data is used, ie. used in TheiaProk-ONT
        )
        ch_tbprofiler_results = TBPROFILER.out.tbparser_inputs
        ch_versions = ch_versions.mix(TBPROFILER.out.versions)

        TBP_PARSER (
            ch_tbprofiler_results,
            params.tbp_parser_config ?: "", // YAML config file for TBP_Parser
            params.tbp_parser_sequencing_method ?: "", // Fills out seq_method in TBP_Parser output
            params.tbp_parser_operator ?: "",
            params.tbp_parser_min_depth ?: 10,
            params.tbp_parser_min_frequency ?: 0.1,
            params.tbp_parser_min_read_support ?: 10,
            params.tbp_parser_min_percent_coverage ?: 100,
            params.tbp_parser_coverage_regions_bed ?: "",
            params.tbp_parser_add_cycloserine_lims ?: false,
            params.tbp_parser_debug ?: true,
            params.tbp_parser_tngs ?: false,
            params.tbp_parser_rrs_frequncy ?: 0.1,
            params.tbp_parser_rrs_read_support ?: 10,
            params.tbp_parser_rr1_frequency ?: 0.1,
            params.tbp_parser_rr1_read_support ?: 10,
            params.tbp_parser_rpob499_frequency ?: 0.1,
            params.tbp_parser_etha237_frequency ?: 0.1,
            params.tbp_parser_expert_rule_regions_bed ?: ""
        )
    }
    
    // Legionella pneumophila typing
    if (merlin_tag == "Legionella pneumophila") {
        LEGSTA (
            ch_assembly
        )
        ch_legsta_results = LEGSTA.out.legsta_results
        ch_versions = ch_versions.mix(LEGSTA.out.versions)
    }
    
    // Staphylococcus aureus typing
    if (merlin_tag == "Staphylococcus aureus") {
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
    }
    
    // Streptococcus pneumoniae typing path
    if (merlin_tag == "Streptococcus pneumoniae") {
        if (params.paired_end && !params.ont_data) {
            SEROBA (
                ch_reads
            )
            ch_seroba_results = SEROBA.out.seroba_serotype
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
            ch_poppunk_results = POPPUNK.out.gps_cluster
            ch_versions = ch_versions.mix(POPPUNK.out.versions)
        }
    }
    
    // Streptococcus pyogenes typing path
    if (merlin_tag == "Streptococcus pyogenes") {
        EMMTYPER (
            ch_assembly,
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
                ch_reads
            )
            ch_emmtypingtool_results = EMMTYPINGTOOL.out.emmtypingtool_results
            ch_versions = ch_versions.mix(EMMTYPINGTOOL.out.versions)
        }
    }
    
    // Haemophilus influenzae typing path
    if (merlin_tag == "Haemophilus influenzae") {
        HICAP (
            ch_assembly,
            params.hicap_min_gene_percent_coverage ?: 0.80,
            params.hicap_min_gene_percent_identity ?: 0.70,
            params.hicap_min_broken_gene_percent_identity ?: 0.80,
            params.hicap_broken_gene_length ?: 60
        )
        ch_hicap_results = HICAP.out.hicap_results_tsv
        ch_versions = ch_versions.mix(HICAP.out.versions)
    }
    
    // Vibrio typing path
    if (merlin_tag == "Vibrio" || merlin_tag == "Vibrio cholerae") {
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
        ABRICATE (
            ch_assembly,
            "vibrio",  // Vibrio database string
            params.abricate_vibrio_min_percent_identity ?: 80,
            params.abricate_vibrio_min_percent_coverage ?: 80
        )
        ch_versions = ch_versions.mix(ABRICATE.out.versions)
    }
    
    // AMR Search - conditional based on organism
    if (params.run_amr_search) {
        // Define taxon code mapping
        def taxon_code_map = [
            "Neisseria gonorrhoeae": "485",
            "Staphylococcus aureus": "1280", 
            "Typhi": "90370",
            "Salmonella typhi": "90370",
            "Streptococcus pneumoniae": "1313",
            "Klebsiella": "570",
            "Klebsiella pneumoniae": "573",
            "Candida auris": "498019",
            "Candidozyma auris": "498019",
            "Vibrio cholerae": "666"
        ]
        
        if (merlin_tag in taxon_code_map.keySet()) {
            AMR_SEARCH (
                ch_assembly,
                taxon_code_map[merlin_tag]
            )
            ch_amr_search_results = AMR_SEARCH.out.amr_results_csv
            ch_versions = ch_versions.mix(AMR_SEARCH.out.versions)
        }
    }
    
    emit:
    // We can remove all emits from MERLIN_MAGIC as the individual modules handle their own publishing
    // The only one we would necessarily need to emit is versions
    amr_search_results         = ch_amr_search_results
    abricate_results           = ch_abricate_results
    kaptive_results            = ch_kaptive_results
    serotypefinder_results     = ch_serotypefinder_results
    ectyper_results            = ch_ectyper_results
    shigatyper_results         = ch_shigatyper_results
    shigeifinder_results       = ch_shigeifinder_results
    stxtyper_results           = ch_stxtyper_results
    virulencefinder_results    = ch_virulencefinder_results
    sonneityper_results        = ch_sonneityper_results
    lissero_results            = ch_lissero_results
    sistr_results              = ch_sistr_results
    seqsero2_results           = ch_seqsero2_results
    genotyphi_results          = ch_genotyphi_results
    kleborate_results          = ch_kleborate_results
    ngmaster_results           = ch_ngmaster_results
    meningotype_results        = ch_meningotype_results
    pasty_results              = ch_pasty_results
    clockwork_results          = ch_clockwork_results
    legsta_results             = ch_legsta_results
    spatyper_results           = ch_spatyper_results
    staphopiasccmec_results    = ch_staphopiasccmec_results
    agrvate_results            = ch_agrvate_results
    seroba_results             = ch_seroba_results
    pbptyper_results           = ch_pbptyper_results
    poppunk_results            = ch_poppunk_results
    emmtyper_results           = ch_emmtyper_results
    emmtypingtool_results      = ch_emmtypingtool_results
    hicap_results              = ch_hicap_results
    srst2_vibrio_results       = ch_srst2_vibrio_results
    vibecheck_results          = ch_vibecheck_results
    
    versions                   = ch_versions
}