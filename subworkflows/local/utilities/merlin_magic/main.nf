include { AMR_SEARCH                   } from '../../../../modules/local/gene_typing/drug_resistance/amr_search/main'
include { HICAP                        } from '../../../../modules/local/species_typing/haemophilus/hicap/main'
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
include { MYCOBACTERIUM_TUBERCULOSIS_SPECIES_TYPING } from '../../../local/species/mycobacterium/main'
include { KLEBSIELLA_TYPING } from '../../../local/species/klebsiella/main'
include { NEISSERIA_GONORRHOEAE_TYPING } from '../../../local/species/neisseria_gonorrhoeae/main'
include { NEISSERIA_MENINGITIDIS_TYPING } from '../../../local/species/neisseria_meningitidis/main'
include { PSEUDOMONAS_AERUGINOSA_SPECIES_TYPING } from '../../../local/species/pseudomonas/main'
include { LEGIONELLA_PNEUMOPHILA_SPECIES_TYPING } from '../../species/legionella_pneumophila/main'
include { STAPHYLOCOCCUS_AUREUS_SPECIES_TYPING } from '../../species/staphylococcus_aureus/main'
include { STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING } from '../../species/streptococcus_pneumoniae/main.nf'

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
        mycobacterium:  it[3] == "Mycobacterium tuberculosis"
        klebsiella:   it[3] == "Klebsiella" || 
                        it[3] == "Klebsiella pneumoniae" || 
                        it[3] == "Klebsiella variicola" || 
                        it[3] == "Klebsiella aerogenes" || 
                        it[3] == "Klebsiella oxytoca"
        neisseria_gonorrhoeae: it[3] == "Neisseria gonorrhoeae"
        neisseria_meningitidis: it[3] == "Neisseria meningitidis"
        pseudomonas_aeruginosa: it[3] == "Pseudomonas aeruginosa"
        legionella_pneumophila: it[3] == "Legionella pneumophila"
        staphylococcus_aureus: it[3] == "Staphylococcus aureus"
        streptococcus_pneumoniae: it[3] == "Streptococcus pneumoniae"
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

    // Prepare for TB
    ch_mtb_with_reads = ch_samples_by_species.mycobacterium
        .filter { meta, assembly, reads, species -> 
            reads && !reads.isEmpty() 
        }

    if (!ch_mtb_with_reads.isEmpty()) {
        MYCOBACTERIUM_TUBERCULOSIS_SPECIES_TYPING(ch_mtb_with_reads)
    }

    // Figured parsing the channel here is simpler, we can revert to doing it in the workflow if we want
    if (!ch_samples_by_species.klebsiella.isEmpty()) {
        // Klebsiella species typing
        KLEBSIELLA_TYPING (
            ch_samples_by_species.klebsiella.map { meta, assembly, reads, species -> [meta, assembly] }
        )
    }
    
    // Neisseria gonorrhoeae typing
    if (!ch_samples_by_species.neisseria_gonorrhoeae.isEmpty()) {
        NEISSERIA_GONORRHOEAE_TYPING (
            ch_samples_by_species.neisseria_gonorrhoeae.map { meta, assembly, reads, species -> [meta, assembly] }
        )
    }
    
    // Neisseria meningitidis
    if (!ch_samples_by_species.neisseria_meningitidis.isEmpty()) {
        NEISSERIA_MENINGITIDIS_TYPING (
            ch_samples_by_species.neisseria_meningitidis
        )
    }

    // Pseudomonas aerugonosa
    if (!ch_samples_by_species.pseudomonas_aeruginosa.isEmpty()) {
        PSEUDOMONAS_AERUGINOSA_SPECIES_TYPING (
            ch_samples_by_species.pseudomonas_aeruginosa
        )
    }

    
    // Legionella pneumophila typing
    if (!ch_samples_by_species.legionella_pneumophila.isEmpty()) {
        LEGIONELLA_PNEUMOPHILA_SPECIES_TYPING (
            ch_samples_by_species.legionella_pneumophila
        )
    }
    
    // Staph aureus typing
    if (!ch_samples_by_species.staphylococcus_aureus.isEmpty()) {
        STAPHYLOCOCCUS_AUREUS_SPECIES_TYPING (
            ch_samples_by_species.staphylococcus_aureus
        )
    }


    // Strep pnuemoniea typing
    if (!ch_samples_by_species.streptococcus_pneumoniae.isEmpty()) {
        STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING (
            ch_samples_by_species.streptococcus_pneumoniae
        )
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
    emmtyper_results           = ch_emmtyper_results
    emmtypingtool_results      = ch_emmtypingtool_results
    hicap_results              = ch_hicap_results
    srst2_vibrio_results       = ch_srst2_vibrio_results
    vibecheck_results          = ch_vibecheck_results
    
    versions                   = ch_versions
}