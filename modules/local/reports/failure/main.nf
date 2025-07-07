process CREATE_FAILURE_REPORT {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(meta), val(fail_type), val(fail_reason)

    output:
    tuple val(meta), path("*_failure_report.json"), emit: failure_report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    create_failure_report.py \\
        --sample_id "${meta.id}" \\
        --fail_type "${fail_type}" \\
        --fail_reason "${fail_reason}" \\
        --output_file "${prefix}_failure_report.json" \\
        --min_reads ${params.min_reads ?: 7472} \\
        --min_basepairs ${params.min_basepairs ?: 2241820} \\
        --min_genome_length ${params.min_genome_length ?: 100000} \\
        --max_genome_length ${params.max_genome_length ?: 18040666} \\
        --min_coverage ${params.min_coverage ?: 10} \\
        --min_proportion ${params.min_proportion ?: 40} \\
        --workflow_name "THEIAPROK_ILLUMINA_PE" \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        create_failure_report.py: \$(create_failure_report.py --help | head -n 1 | sed 's/.*script to //' | sed 's/ for.*//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_failure_report.json
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        create_failure_report.py: "1.0.0"
    END_VERSIONS
    """
}