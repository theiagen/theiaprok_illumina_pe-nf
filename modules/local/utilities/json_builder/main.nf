process UTILITY_JSON_BUILDER {
    tag "${meta.id}"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/theiagen/krakentools:d4a2fbe"

    input:
    tuple val(meta), path(value_files)
    path('json_builder.py')
    
    output:
    tuple val(meta), path("*.json"), emit: value_json_output

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python3 json_builder.py --value_files "${value_files}" --prefix "${prefix}"
    """
}