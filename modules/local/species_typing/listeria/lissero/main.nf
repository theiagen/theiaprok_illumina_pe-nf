process LISSERO {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/lissero:0.4.9--py_0"

    input:
    tuple val(meta), path(assembly)
    val min_percent_identity
    val min_percent_coverage

    output:
    tuple val(meta), path("*.tsv"), emit: lissero_results
    tuple val(meta), path("lissero_SEROTYPE.txt"), emit: lissero_serotype
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_id_arg = min_percent_identity ? "${min_percent_identity}" : 95.0
    def min_cov_arg = min_percent_coverage ? "${min_percent_coverage}" : 95.0 
    
    """
    lissero \\
        --min_id ${min_id_arg} \\
        --min_cov ${min_cov_arg} \\
        ${assembly} \\
        ${args} \\
        > ${prefix}.tsv

    # pull out serotype
    if [ -f ${prefix}.tsv ] && [ \$(wc -l < ${prefix}.tsv) -gt 1 ]; then
        serotype=\$(tail -n+2 ${prefix}.tsv | cut -f2)
    else
        serotype="No serotype predicted"
    fi
    echo "\$serotype" > lissero_SEROTYPE.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lissero: \$(lissero --version 2>&1 | sed 's/^.*LisSero //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    echo "No serotype predicted" > lissero_SEROTYPE.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lissero: \$(lissero --version 2>&1 | sed 's/^.*LisSero //')
    END_VERSIONS
    """
}