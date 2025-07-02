process ABRICATE {
    tag "$meta.id"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/staphb/abricate:1.0.1-abaum-plasmid"

    input:
    tuple val(meta), path(assembly)
    val database
    val min_percent_identity
    val min_percent_coverage

    output:
    tuple val(meta), path("*_abricate_hits.tsv"), emit: results
    tuple val(meta), path("ABRICATE_GENES_values.txt"), emit: genes_file
    tuple val(meta), val(database), emit: database_used
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def minid_arg = min_percent_identity ? "--minid ${min_percent_identity}" : ""
    def mincov_arg = min_percent_coverage ? "--mincov ${min_percent_coverage}" : ""
    
    """
    date | tee DATE
    abricate --list
    abricate --check
    
    abricate \\
        --db ${database} \\
        ${minid_arg} \\
        ${mincov_arg} \\
        --threads ${task.cpus} \\
        --nopath \\
        ${args} \\
        ${assembly} > ${prefix}_abricate_hits.tsv
    
    # parse out gene names into list of strings, comma-separated, final comma at end removed by sed
    abricate_genes=\$(awk -F '\\t' '{ print \$6 }' ${prefix}_abricate_hits.tsv | tail -n+2 | tr '\\n' ',' | sed 's/.\$//')
    # if variable for list of genes is EMPTY, write string saying it is empty to float to Terra table
    if [ -z "\${abricate_genes}" ]; then
       abricate_genes="No genes detected by ABRicate"
    fi
    # create final output strings
    echo "\${abricate_genes}" > ABRICATE_GENES_values.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$(abricate -v)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_abricate_hits.tsv
    echo "No genes detected by ABRicate" > ABRICATE_GENES_values.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$(abricate -v)
    END_VERSIONS
    """
}