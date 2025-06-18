process FASTP_PE {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/fastp:0.23.2"

    input:
    tuple val(meta), path(read1), path(read2)
    val fastp_window_size
    val fastp_quality_trim_score
    val fastp_min_length
    val fastp_args

    output:
    tuple val(meta), path("*P.fastq.gz"), emit: trimmed_reads
    tuple val(meta), path("*U.fastq.gz"), emit:  unpaired_trimmed_reads
    tuple val(meta), path("*_fastp.html"), emit: fastp_stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def fastp_args = fastp_args ?: "--detect_adapter_for_pe -g -5 20 -3 20"
    def prefix = task.ext.prefix ?: "${meta.id}"
    def window_size = fastp_window_size ?: 20
    def quality_score = fastp_quality_trim_score ?: 30
    def min_length = fastp_min_length ?: 50
    
    """
    date | tee DATE
    
    fastp \\
        --in1 ${read1} \\
        --in2 ${read2} \\
        --out1 ${prefix}_1P.fastq.gz \\
        --out2 ${prefix}_2P.fastq.gz \\
        --unpaired1 ${prefix}_1U.fastq.gz \\
        --unpaired2 ${prefix}_2U.fastq.gz \\
        --cut_right \\
        --cut_right_window_size ${window_size} \\
        --cut_right_mean_quality ${quality_score} \\
        --length_required ${min_length} \\
        --thread ${task.cpus} \\
        ${fastp_args} \\
        --html ${prefix}_fastp.html \\
        --json ${prefix}_fastp.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed 's/fastp //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_1P.fastq.gz
    touch ${prefix}_2P.fastq.gz
    touch ${prefix}_1U.fastq.gz
    touch ${prefix}_2U.fastq.gz
    touch ${prefix}_fastp.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: 0.23.2
    END_VERSIONS
    """
}