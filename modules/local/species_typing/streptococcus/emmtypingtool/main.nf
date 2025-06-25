process EMMTYPINGTOOL {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/emmtypingtool:0.0.1"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.emmtypingtool.xml"), emit: emmtypingtool_results
    tuple val(meta), path("EMM_TYPE"), emit: emmtypingtool_emm_type
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (reads.size() != 2) {
        error "EMMTYPINGTOOL requires exactly two input reads (paired-end). Found: ${reads.size()}"
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '0.2.0' // No option to get version from tool
    
    
    """
    emm_typing.py \\
      -m /db \\
      -1 ${reads[0]} \\
      -2 ${reads[1]} \\
      -o output_dir \\
        ${args}

    grep "Final_EMM_type" output_dir/*.results.xml | sed -n 's/.*value="\\([^"]*\\)".*/\\1/p' | tee EMM_TYPE
    mv output_dir/*.results.xml ${prefix}.emmtypingtool.xml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emmtypingtool: ${VERSION}
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '0.2.0' // No option to get version from tool
    """
    touch ${prefix}.emmtypingtool.xml
    touch EMM_TYPE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emmtypingtool: ${VERSION}
    END_VERSIONS
    """
}