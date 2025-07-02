process EMMTYPER {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/emmtyper:0.2.0--py_0"

    input:
    tuple val(meta), path(assembly)
    val workflow_type
    val cluster_distance
    val min_percent_identity
    val culling_limit
    val mismatch
    val align_diff
    val gap
    val min_perfect
    val min_good
    val max_size


    output:
    tuple val(meta), path("*_emmtyper.tsv"), emit: emmtyper_results
    tuple val(meta), path("emmtyper_EMM_TYPE"), emit: emmtyper_emm_type
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def workflow_type_arg = workflow_type ? workflow_type : 'blast'
    def cluster_distance_arg = cluster_distance ? cluster_distance : '500'
    def min_percent_identity_arg = min_percent_identity ? min_percent_identity : 95
    def culling_limit_arg = culling_limit ? culling_limit : 5
    def mismatch_arg = mismatch ? mismatch : 4
    def align_diff_arg = align_diff ? align_diff : 5
    def gap_arg = gap ? gap : 2
    def min_perfect_arg = min_perfect ? min_perfect : 15
    def min_good_arg = min_good ? min_good : 15
    def max_size_arg = max_size ? max_size : 2000
    
    
    """
    emmtyper \\
        --workflow ${workflow_type_arg} \\
        --cluster-distance ${cluster_distance_arg} \\
        --percent-identity ${min_percent_identity_arg} \\
        --culling-limit ${culling_limit_arg} \\
        --mismatch ${mismatch_arg} \\
        --align-diff ${align_diff_arg} \\
        --gap ${gap_arg} \\
        --min-perfect ${min_perfect_arg} \\
        --min-good ${min_good_arg} \\
        --max-size ${max_size_arg} \\
        --output-format verbose \\
        ${args} \\
        ${assembly} > ${prefix}_emmtyper.tsv

    # emm type is in column 4 for verbose output format
    awk -F "\\t" '{print \$4}' ${prefix}_emmtyper.tsv > emmtyper_EMM_TYPE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emmtyper:\$(emmtyper --version 2>&1 | sed 's/^.*emmtyper v//') 
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_emmtyper.tsv
    touch EMM_TYPE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emmtyper: \$(emmtyper --version 2>&1) | sed 's/^.*emmtyper v//')
    END_VERSIONS
    """
}