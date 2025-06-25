process SRST2_VIBRIO {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/srst2:0.2.0-vcholerae"

    input:
    tuple val(meta), path(reads)
    val min_percent_coverage
    val max_divergence
    val min_depth
    val min_edge_depth
    val gene_max_mismatch

    output:
    tuple val(meta), path("*.detailed.tsv")    , emit: srst2_detailed_tsv
    tuple val(meta), path("ctxA")              , emit: srst2_ctxa
    tuple val(meta), path("ompW")              , emit: srst2_ompw
    tuple val(meta), path("toxR")              , emit: srst2_toxr
    tuple val(meta), path("BIOTYPE")           , emit: srst2_biotype
    tuple val(meta), path("SEROGROUP")         , emit: srst2_serogroup
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_files = reads instanceof List ? reads : [reads]
    def input_reads = ""
    // Will probably change this, just need to test with a bit more flexibility for now
    if (input_files.size() == 1) {
        input_reads = "--input_se ${input_files[0]}"
    } else {
        // Detect read naming pattern and set appropriate forward/reverse identifiers
        def read1_name = input_files[0].toString()
        def read2_name = input_files[1].toString()
        
        def forward_id = ""
        def reverse_id = ""
        
        // Check for different naming patterns
        if (read1_name.contains("_1.clean") && read2_name.contains("_2.clean")) {
            // TheiaProk naming: sample_1.clean.fastq.gz, sample_2.clean.fastq.gz
            forward_id = "_1.clean"
            reverse_id = "_2.clean"
        } else if (read1_name.contains("_1.fastq") && read2_name.contains("_2.fastq")) {
            // Standard naming: sample_1.fastq.gz, sample_2.fastq.gz
            forward_id = "_1.fastq"
            reverse_id = "_2.fastq"
        } else if (read1_name.contains("_R1") && read2_name.contains("_R2")) {
            // Alternative naming: sample_R1.fastq.gz, sample_R2.fastq.gz - for some tests
            forward_id = "_R1"
            reverse_id = "_R2"
        } else {
            // Default fallback - use basic _1 and _2 identifiers
            forward_id = "_1"
            reverse_id = "_2"
        }
        
        input_reads = "--input_pe ${input_files[0]} ${input_files[1]} --forward ${forward_id} --reverse ${reverse_id}"
    }
    
    """
    # Run SRST2
    srst2 \\
        ${input_reads} \\
        --gene_db /vibrio-cholerae-db/vibrio_230224.fasta \\
        --output ${prefix} \\
        --min_coverage ${min_percent_coverage} \\
        --max_divergence ${max_divergence} \\
        --min_depth ${min_depth} \\
        --min_edge_depth ${min_edge_depth} \\
        --gene_max_mismatch ${gene_max_mismatch} \\
        ${args}
    
    # Capture output TSV
    mv ${prefix}__genes__*__results.txt ${prefix}.tsv || echo "No results" > ${prefix}.tsv

    # Capture detailed output TSV - not available if no results are outputted
    mv ${prefix}__fullgenes__*__results.txt ${prefix}.detailed.tsv || echo "No results" > ${prefix}.detailed.tsv

    vibrio_parser.py \\
        ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        srst2: \$(srst2 --version 2>&1 | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.detailed.tsv
    echo "present" > ctxA
    echo "present" > ompW
    echo "present" > toxR
    echo "tcpA_ElTor" > BIOTYPE
    echo "O1" > SEROGROUP

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        srst2: \$(srst2 --version 2>&1 | head -n1)
    END_VERSIONS
    """
}