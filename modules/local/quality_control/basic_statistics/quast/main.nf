process QUAST {
    tag "$meta.id"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/staphb/quast:5.0.2"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${meta.id}_report.tsv"), emit: report
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_contig_length = params.quast_min_contig_length ?: 500
    """
    quast.py ${assembly} \\
        --output-dir . \\
        --threads ${task.cpus} \\
        --min-contig ${min_contig_length}
    
    mv report.tsv ${meta.id}_report.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    touch ${meta.id}_report.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast --version)
    END_VERSIONS
    """
}
