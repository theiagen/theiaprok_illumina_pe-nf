process LEGSTA {
    tag "$meta.id"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/biocontainers/legsta:0.5.1--hdfd78af_2"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.tsv"), emit: legsta_results
    tuple val(meta), path("LEGSTA_SBT.txt"), emit: legsta_predicted_sbt
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    legsta \\
      ${assembly} > ${prefix}.tsv
    
    # parse outputs
    SBT=""
    if [ ! -f ${prefix}.tsv ]; then
      SBT="No SBT predicted"
    else
      SBT="ST\$(tail -n 1 ${prefix}.tsv | cut -f 2)"
        if [ "\$SBT" == "ST-" ]; then
          SBT="No SBT predicted"
        else
          if [ "\$SBT" == "ST" ]; then
            SBT="No SBT predicted"
          fi
        fi  
    fi

    echo \$SBT > LEGSTA_SBT.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        legsta: \$(legsta --version 2>&1 | sed 's/^.*legsta //; s/ .*\$//;')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}.tsv"
    touch "LEGSTA_SBT.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        legsta: \$(\$(legsta --version 2>&1) | sed 's/^.*legsta //; s/ .*\$//;')
    END_VERSIONS
    """
}