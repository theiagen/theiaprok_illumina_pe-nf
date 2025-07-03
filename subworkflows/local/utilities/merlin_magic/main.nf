// New Subworkflows 
include { ACINETOBACTER_SPECIES_TYPING } from '../../species/acinetobacter_baumannii/main'
include { LISTERIA_SPECIES_TYPING } from '../../species/listeria/main'
include { SALMONELLA_SPECIES_TYPING } from '../../species/salmonella/main'
include { ESCHERICHIA_SHIGELLA_TYPING } from '../../species/ecoli_shigella/main'
include { MYCOBACTERIUM_TUBERCULOSIS_SPECIES_TYPING } from '../../species/mycobacterium/main'
include { KLEBSIELLA_TYPING } from '../../species/klebsiella/main'
include { NEISSERIA_GONORRHOEAE_TYPING } from '../../species/neisseria_gonorrhoeae/main'
include { NEISSERIA_MENINGITIDIS_TYPING } from '../../species/neisseria_meningitidis/main'
include { PSEUDOMONAS_AERUGINOSA_SPECIES_TYPING } from '../../species/pseudomonas/main'
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

    ch_versions = Channel.empty()
    
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
    ch_versions = ch_versions.mix(ACINETOBACTER_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))

    LISTERIA_SPECIES_TYPING(ch_samples_by_species.listeria)
    ch_versions = ch_versions.mix(LISTERIA_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    SALMONELLA_SPECIES_TYPING(ch_samples_by_species.salmonella)
    ch_versions = ch_versions.mix(SALMONELLA_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    ESCHERICHIA_SHIGELLA_TYPING(ch_samples_by_species.ecoli_shigella)
    ch_versions = ch_versions.mix(ESCHERICHIA_SHIGELLA_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Prepare MTB with reads filter
    ch_mtb_with_reads = ch_samples_by_species.mycobacterium
        .filter { meta, assembly, reads, species ->
            reads && !(reads instanceof List ? reads.isEmpty() : reads.toString().isEmpty())
        }
    MYCOBACTERIUM_TUBERCULOSIS_SPECIES_TYPING(ch_mtb_with_reads)
    ch_versions = ch_versions.mix(MYCOBACTERIUM_TUBERCULOSIS_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Klebsiella species typing
    KLEBSIELLA_TYPING (
        ch_samples_by_species.klebsiella.map { meta, assembly, reads, species -> [meta, assembly] }
    )
    ch_versions = ch_versions.mix(KLEBSIELLA_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Neisseria gonorrhoeae typing
    NEISSERIA_GONORRHOEAE_TYPING (
        ch_samples_by_species.neisseria_gonorrhoeae.map { meta, assembly, reads, species -> [meta, assembly] }
    )
    ch_versions = ch_versions.mix(NEISSERIA_GONORRHOEAE_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Neisseria meningitidis
    NEISSERIA_MENINGITIDIS_TYPING (
        ch_samples_by_species.neisseria_meningitidis
    )
    ch_versions = ch_versions.mix(NEISSERIA_MENINGITIDIS_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Pseudomonas aeruginosa
    PSEUDOMONAS_AERUGINOSA_SPECIES_TYPING (
        ch_samples_by_species.pseudomonas_aeruginosa
    )
    ch_versions = ch_versions.mix(PSEUDOMONAS_AERUGINOSA_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Legionella pneumophila typing
    LEGIONELLA_PNEUMOPHILA_SPECIES_TYPING (
        ch_samples_by_species.legionella_pneumophila
    )
    ch_versions = ch_versions.mix(LEGIONELLA_PNEUMOPHILA_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Staph aureus typing
    STAPHYLOCOCCUS_AUREUS_SPECIES_TYPING (
        ch_samples_by_species.staphylococcus_aureus
    )
    ch_versions = ch_versions.mix(STAPHYLOCOCCUS_AUREUS_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Strep pneumoniae typing
    STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING (
        ch_samples_by_species.streptococcus_pneumoniae
    )
    ch_versions = ch_versions.mix(STREPTOCOCCUS_PNEUMONIAE_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Strep pyogenes typing
    STREPTOCOCCUS_PYOGENES_SPECIES_TYPING (
        ch_samples_by_species.streptococcus_pyogenes
    )
    ch_versions = ch_versions.mix(STREPTOCOCCUS_PYOGENES_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))
    // Haemophilus influenzae typing
    HAEMOPHILUS_INFLUENZAE_SPECIES_TYPING (
        ch_samples_by_species.haemophilus_influenzae.map { meta, assembly, reads, species -> [meta, assembly] }
    )
    ch_versions = ch_versions.mix(HAEMOPHILUS_INFLUENZAE_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))

    VIBRIO_SPECIES_TYPING (
        ch_samples_by_species.vibrio
    )
    ch_versions = ch_versions.mix(VIBRIO_SPECIES_TYPING.out.versions.ifEmpty(Channel.empty()))

    // AMR Search - conditional based on organism
    if (params.run_amr_search) {
        AMR_SEARCH (
            ch_samples_by_species.map { meta, assembly, reads, species -> [meta, assembly, species] }
        )
        ch_versions = ch_versions.mix(AMR_SEARCH.out.versions)
    }
    
    emit:
    versions = ch_versions

}