process FILTER_CONTIGS {
    tag "$meta.id"
    label "process_low"
    
    container "us-docker.pkg.dev/general-theiagen/staphb/mykrobe:0.12.1"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path('*_filtered_contigs.fasta'), emit: filtered_contigs
    tuple val(meta), path('*_filtering_metrics.txt') , emit: filter_metrics
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_length = params.filter_contigs_min_length ?: 1000
    def min_coverage = params.filter_contigs_min_coverage ?: 2.0
    
    // Handle boolean flags properly - only add flag if true
    def skip_length = params.filter_contigs_skip_length_filter ? '--skip-length-filter' : ''
    def skip_coverage = params.filter_contigs_skip_coverage_filter ? '--skip-coverage-filter' : ''
    def skip_homopolymer = params.filter_contigs_skip_homopolymer_filter ? '--skip-homopolymer-filter' : ''
    
    """
    echo "Filtering contigs from ${assembly}" >&2
    
    assembly_shovilter.py \\
        -i ${assembly} \\
        -o ${prefix}_filtered_contigs.fasta \\
        -m ${prefix}_filtering_metrics.txt \\
        --minlen ${min_length} \\
        --mincov ${min_coverage} \\
        ${skip_length} \\
        ${skip_coverage} \\
        ${skip_homopolymer}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shovilter: "0.2"
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_filtered_contigs.fasta
    touch ${prefix}_filtering_metrics.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shovilter: "0.2"
    END_VERSIONS
    """
}