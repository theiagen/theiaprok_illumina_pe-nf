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
include { STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING } from '../../species/streptococcus_pneumoniae/main'
include { STREPTOCOCCUS_PYOGENES_SPECIES_TYPING } from '../../species/streptococcus_pyogenes/main'
include { HAEMOPHILUS_INFLUENZAE_SPECIES_TYPING } from '../../species/haemophilus_influenzae/main'
include { VIBRIO_SPECIES_TYPING } from '../../species/vibrio/main'
include { AMR_SEARCH } from '../../../../modules/local/gene_typing/drug_resistance/amr_search/main'

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
        streptococcus_pyogenes: it[3] == "Streptococcus pyogenes"
        haemophilus_influenzae: it[3] == "Haemophilus influenzae"
        vibrio: it[3] == "Vibrio" || 
                 it[3] == "Vibrio cholerae"
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

    // Strep pneumoniae typing
    if (!ch_samples_by_species.streptococcus_pneumoniae.isEmpty()) {
        STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING (
            ch_samples_by_species.streptococcus_pneumoniae
        )
    }

    // Strep pyogenes typing
    if (!ch_samples_by_species.streptococcus_pyogenes.isEmpty()) {
        STREPTOCOCCUS_PYOGENES_SPECIES_TYPING (
            ch_samples_by_species.streptococcus_pyogenes
        )
    }

    // Haemophilus influenzae typing
    if (!ch_samples_by_species.haemophilus_influenzae.isEmpty()) {
        HAEMOPHILUS_INFLUENZAE_SPECIES_TYPING (
            ch_samples_by_species.haemophilus_influenzae.map { meta, assembly, reads, species -> [meta, assembly] }
        )
    }

    // Vibrio typing 
    if (!ch_samples_by_species.vibrio.isEmpty()) {
        VIBRIO_SPECIES_TYPING (
            ch_samples_by_species.vibrio
        )
    }
    
    // AMR Search - conditional based on organism
    if (params.run_amr_search) {
        AMR_SEARCH (
            ch_samples_by_species.map { meta, assembly, reads, species -> [meta, assembly, species] }
        )
        ch_amr_search_results = AMR_SEARCH.out.amr_results_csv
        ch_versions = ch_versions.mix(AMR_SEARCH.out.versions)
    }
    // We can remove all emits from MERLIN_MAGIC as the individual modules handle their own publishing
    // The only one we would necessarily need to emit is versions

}