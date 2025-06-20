process BWA_MEM {
    tag "$meta.id"
    label "process_low"
    
    container "us-docker.pkg.dev/general-theiagen/staphb/ivar:1.3.1-titan"

    input:
    tuple val(meta), path(reads), path(reference)

    output:
    tuple val(meta), path('*.sorted.bam')    , emit: bam
    tuple val(meta), path('*.sorted.bam.bai'), emit: bai
    tuple val(meta), path('*_R1.fastq.gz')  , emit: fastq_1
    tuple val(meta), path('*_R2.fastq.gz')  , emit: fastq_2, optional: true
    tuple val(meta), path('*_unaligned_R1.fastq.gz'), emit: unaligned_1
    tuple val(meta), path('*_unaligned_R2.fastq.gz'), emit: unaligned_2, optional: true
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read_group = meta.read_group ? "-R ${meta.read_group}" : "-R '@RG\\tID:${prefix}\\tSM:${prefix}'"
    def reads_command = meta.single_end ? "${reads}" : "${reads[0]} ${reads[1]}"
    
    """
    # Index reference
    bwa index ${reference}

    # Align reads
    bwa mem \\
        -t ${task.cpus} \\
        ${read_group} \\
        ${reference} \\
        ${reads_command} \\
        ${args} | \\
    samtools sort \\
        -@ ${task.cpus} \\
        -o ${prefix}.sorted.bam

    # Create separate BAM for aligned reads only (no secondary/supplementary)
    samtools view \\
        -@ ${task.cpus} \\
        -F 0x904 \\
        -b \\
        -o ${prefix}.sorted.aligned-only.bam \\
        ${prefix}.sorted.bam

    # Create BAM for unaligned reads
    samtools view \\
        -@ ${task.cpus} \\
        -f 4 \\
        -b \\
        -o ${prefix}.sorted.unaligned-reads.bam \\
        ${prefix}.sorted.bam

    # Extract FASTQ files
    if [[ "${meta.single_end}" == "true" ]]; then
        # Single-end reads
        samtools fastq \\
            -@ ${task.cpus} \\
            -F 4 \\
            -0 ${prefix}_R1.fastq.gz \\
            ${prefix}.sorted.aligned-only.bam

        samtools fastq \\
            -@ ${task.cpus} \\
            -f 4 \\
            -0 ${prefix}_unaligned_R1.fastq.gz \\
            ${prefix}.sorted.unaligned-reads.bam
    else
        # Paired-end reads
        samtools fastq \\
            -@ ${task.cpus} \\
            -F 4 \\
            -1 ${prefix}_R1.fastq.gz \\
            -2 ${prefix}_R2.fastq.gz \\
            ${prefix}.sorted.aligned-only.bam

        samtools fastq \\
            -@ ${task.cpus} \\
            -f 4 \\
            -1 ${prefix}_unaligned_R1.fastq.gz \\
            -2 ${prefix}_unaligned_R2.fastq.gz \\
            ${prefix}.sorted.unaligned-reads.bam
    fi

    # Index BAM files
    samtools index ${prefix}.sorted.bam
    samtools index ${prefix}.sorted.unaligned-reads.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(echo \$(bwa 2>&1) | sed 's/^.*Version: //; s/Contact:.*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.sorted.bam
    touch ${prefix}.sorted.bam.bai
    touch ${prefix}_R1.fastq
    touch ${prefix}_unaligned_R1.fastq
    if [[ "${meta.single_end}" != "true" ]]; then
        touch ${prefix}_R2.fastq
        touch ${prefix}_unaligned_R2.fastq

    fi

    gzip *.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(echo \$(bwa 2>&1) | sed 's/^.*Version: //; s/Contact:.*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}