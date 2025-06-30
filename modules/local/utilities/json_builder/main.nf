process UTILITY_JSON_BUILDER {
    tag "${meta.id}"
    label 'process_low'

    conda "python=3.9.17"

    input:
    tuple val(meta), path(value_files)
    
    output:
    tuple val(meta), path("*.json"), emit: value_json_output

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python $projectDir/bin/json_builder.py --value_files "${value_files}" --prefix "${prefix}"
    """
}