process SKESA {
    tag "$meta.id"
    label "process_medium"
    
    container "us-docker.pkg.dev/general-theiagen/staphb/skesa:2.4.0"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*_contigs.fa'), emit: assembly_fasta
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_contig_len = params.min_contig_length ?: 1
    def maxmem = task.memory.toGiga()
    def reads_input = meta.single_end ? "--fastq ${reads[0]}" : "--fastq ${reads[0]},${reads[1]} --use_paired_ends"
    
    """
    skesa \\
        --gz \\
        ${reads_input} \\
        --contigs_out ${prefix}_skesa_contigs.fa \\
        --min_contig ${min_contig_len} \\
        --memory ${maxmem} \\
        --cores ${task.cpus} \\
        --vector_percent 1 \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        skesa: \$(skesa --version 2>&1 | grep "SKESA" | sed -E 's/^.*SKESA ([0-9.]+).*/\\1/')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_skesa_contigs.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        skesa: \$(skesa --version 2>&1 | grep "SKESA" | sed -E 's/^.*SKESA ([0-9.]+).*/\\1/')
    END_VERSIONS
    """
}