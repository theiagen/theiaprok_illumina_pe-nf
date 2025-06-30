#!/usr/bin/env nextflow
/*
========================================================================================
    THEIAPROK ILLUMINA PE WORKFLOW
========================================================================================
    De-novo genome assembly, taxonomic ID, and QC of paired-end bacterial NGS data
----------------------------------------------------------------------------------------
*/

include { THEIAPROK_ILLUMINA_PE } from './workflows/theiaprok/main'


workflow {
    // Kind of lazy ways to hand inpupt. Can create a subworkflow for handling input reads later
    if (params.input) {
        Channel
            .fromPath(params.input, checkIfExists: true)
            .splitCsv(header: true)
            .map { row ->
                def meta = [:]
                meta.id = row.sample ?: row.samplename ?: row.id
                def read1 = file(row.read1 ?: row.fastq_1, checkIfExists: true)
                def read2 = file(row.read2 ?: row.fastq_2, checkIfExists: true)
                [meta, [ read1, read2 ] ]
            }
            .set { ch_input_reads }
    } else if (params.read1 && params.read2) {
        // Direct read inputs for testing
        def meta = [:]
        meta.id = params.samplename
        Channel
            .of([meta, file(params.read1, checkIfExists: true), file(params.read2, checkIfExists: true)])
            .set { ch_input_reads }
    } else {
        error "Please provide either --input samplesheet.csv or --read1/--read2 with --samplename"
    }
    
    THEIAPROK_ILLUMINA_PE (
        ch_input_reads
    )
}
