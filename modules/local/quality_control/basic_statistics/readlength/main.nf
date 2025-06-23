process READLENGTH {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/bbtools:38.76"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("AVERAGE_READ_LENGTH.txt"), emit: average_read_length
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def read1 = reads[0]
    def read2 = reads[1]
    if (!read1 || !read2) {
        error "Both read1 and read2 must be provided. Received: read1=${read1}, read2=${read2}"
    }

    """

    readlength.sh in=${read1} > STDOUT_FORWARD
    readlength.sh in=${read2} > STDOUT_REVERSE

    avg_forward=\$(cat STDOUT_FORWARD | grep "#Avg:" | cut -f 2)
    avg_reverse=\$(cat STDOUT_REVERSE | grep "#Avg:" | cut -f 2)

    echo "Average read length for forward reads: \$avg_forward"
    echo "Average read length for reverse reads: \$avg_reverse"

    results=\$(awk "BEGIN { printf \\"%.2f\\", (\$avg_forward + \$avg_reverse) / 2 }")

    echo "\$results" > AVERAGE_READ_LENGTH.txt


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbtools: \$(bbversion.sh)
    END_VERSIONS
    """

    stub:
    """
    echo "1000" > AVERAGE_READ_LENGTH.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbtools: \$(bbversion.sh)
    END_VERSIONS
    """
}