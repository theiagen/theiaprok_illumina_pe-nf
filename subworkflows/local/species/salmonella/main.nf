include { SISTR     } from '../../../../modules/local/species_typing/salmonella/sistr/main'
include { SEQSERO2  } from '../../../../modules/local/species_typing/salmonella/seqsero2/main'
include { GENOTYPHI } from '../../../../modules/local/species_typing/salmonella/genotyphi/main'

workflow SALMONELLA_SPECIES_TYPING {

    take:
    ch_salmonella // Channel of tuples [meta, assembly, reads, species]

    main:

    ch_versions = Channel.empty()
    ch_sistr_results = Channel.empty()
    ch_seqsero2_results = Channel.empty()
    ch_genotyphi_results = Channel.empty()

    // Extract assembly for SISTR
    ch_assembly = ch_salmonella.map { meta, assembly, reads, species -> [meta, assembly] }
    
    // Extract reads for SeqSero2 (when needed)
    ch_reads = ch_salmonella.map { meta, assembly, reads, species -> [meta, reads] }

    // Run SISTR on assembly
    SISTR (
        ch_assembly
    )
    ch_sistr_results = SISTR.out.sistr_result
    ch_versions = ch_versions.mix(SISTR.out.versions)
    
    // SeqSero2 - different input based on data type
    if (params.ont_data || params.assembly_only) {
        SEQSERO2 (
            ch_assembly
        )
    } else {
        SEQSERO2 (
            ch_reads
        )
    }
    ch_seqsero2_results = SEQSERO2.out.seqsero2_report
    ch_versions = ch_versions.mix(SEQSERO2.out.versions)
    
    // GenotypHi for Typhi - only if not assembly_only
    if (!params.assembly_only) {
        // Get serotype predictions to check for Typhi
        ch_typhi_check = SEQSERO2.out.seqsero_serotype
            .join(SISTR.out.sistr_predicted_serotype)
            .filter { meta, seqsero_file, sistr_file ->
                def seqsero_content = seqsero_file.text.trim()
                def sistr_content = sistr_file.text.trim()
                seqsero_content == "Typhi" || sistr_content == "Typhi"
            }
            .map { meta, seqsero_file, sistr_file -> meta }
        
        ch_typhi_reads = ch_reads
            .join(ch_typhi_check)
            .map { meta, reads, check -> [meta, reads] }
        
        GENOTYPHI (
            ch_typhi_reads
        )
        ch_genotyphi_results = GENOTYPHI.out.genotyphi_report
        ch_versions = ch_versions.mix(GENOTYPHI.out.versions)
    }

    emit:
    sistr_results = ch_sistr_results
    seqsero2_results = ch_seqsero2_results
    genotyphi_results = ch_genotyphi_results
    
    versions = ch_versions
}