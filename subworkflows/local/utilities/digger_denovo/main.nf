#!/usr/bin/env nextflow

/*
========================================================================================
    DIGGER DE NOVO ASSEMBLY SUBWORKFLOW
========================================================================================
    Testing conversion from our WDL
----------------------------------------------------------------------------------------
*/

include { SPADES         } from '../../../../modules/local/assembly/spades/main'
include { MEGAHIT        } from '../../../../modules/local/assembly/megahit/main'
include { SKESA          } from '../../../../modules/local/assembly/skesa/main'
include { BWA_MEM        } from '../../../../modules/local/alignment/bwa/main'
include { PILON          } from '../../../../modules/local/polishing/pilon/main'
include { FILTER_CONTIGS } from '../../../../modules/local/quality_control/contig_filtering/shovilter/main'

workflow DIGGER_DENOVO {
    
    take:
    ch_reads        // channel: [ val(meta), [ reads ] ]
    
    main:
    
    ch_versions = Channel.empty()
    
    ch_assembly = Channel.empty()
    ch_assembly_gfa = Channel.empty()
    
    if (params.assembler == 'spades') {
        SPADES (
            ch_reads,
            params.kmers ?: [],
            params.spades_type ?: 'isolate'
        )
        ch_assembly = SPADES.out.assembly_fasta
        ch_assembly_gfa = SPADES.out.assembly_gfa
        ch_versions = ch_versions.mix(SPADES.out.versions)
    }
    else if (params.assembler == 'megahit') {
        MEGAHIT (
            ch_reads,
            params.kmers ?: ''
        )
        ch_assembly = MEGAHIT.out.assembly_fasta
        ch_versions = ch_versions.mix(MEGAHIT.out.versions)
    }
    else if (params.assembler == 'skesa') {
        SKESA (
            ch_reads
        )
        ch_assembly = SKESA.out.assembly_fasta
        ch_versions = ch_versions.mix(SKESA.out.versions)
    }
    else {
        error "Invalid assembler specified: ${params.assembler}. Valid options: spades, megahit, skesa"
    }
    
    ch_polished_assembly = ch_assembly
    ch_pilon_changes = Channel.empty()
    ch_pilon_vcf = Channel.empty()
    
    if (params.call_pilon) {
        // Prepare reads and assembly for BWA
        ch_bwa_input = ch_reads
            .join(ch_assembly)
            .map { meta, reads, assembly -> 
                [ meta, reads, assembly ]
            }
        
        BWA_MEM (
            ch_bwa_input
        )
        ch_versions = ch_versions.mix(BWA_MEM.out.versions)
        
        // Prepare input for Pilon
        ch_pilon_input = ch_assembly
            .join(BWA_MEM.out.bam)
            .join(BWA_MEM.out.bai)
            .map { meta, assembly, bam, bai ->
                [ meta, assembly, bam, bai ]
            }
        
        PILON (
            ch_pilon_input
        )
        ch_polished_assembly = PILON.out.improved_assembly
        ch_pilon_changes = PILON.out.changes
        ch_pilon_vcf = PILON.out.vcf
        ch_versions = ch_versions.mix(PILON.out.versions)
    }
    
    ch_final_assembly = ch_polished_assembly
    ch_filter_metrics = Channel.empty()
    
    if (params.run_filter_contigs) {
        FILTER_CONTIGS (
            ch_polished_assembly
        )
        ch_final_assembly = FILTER_CONTIGS.out.filtered_contigs
        ch_filter_metrics = FILTER_CONTIGS.out.filter_metrics
        ch_versions = ch_versions.mix(FILTER_CONTIGS.out.versions)
    }
    
    emit:
    assembly           = ch_final_assembly         // channel: [ val(meta), path(assembly) ]
    contigs_gfa        = ch_assembly_gfa          // channel: [ val(meta), path(gfa) ]
    filter_metrics     = ch_filter_metrics        // channel: [ val(meta), path(metrics) ]
    pilon_changes      = ch_pilon_changes         // channel: [ val(meta), path(changes) ]
    pilon_vcf          = ch_pilon_vcf             // channel: [ val(meta), path(vcf) ]
    versions           = ch_versions              // channel: [ versions.yml ]
}