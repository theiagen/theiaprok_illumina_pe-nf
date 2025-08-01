process FASTQC {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/fastqc:0.12.1"

    input:
    tuple val(meta), path(reads)
    val task_prefix

    output:
    tuple val(meta), path("*_R1_fastqc.html"), emit: read1_fastqc_html
    tuple val(meta), path("*_R1_fastqc.zip"), emit: read1_fastqc_zip
    tuple val(meta), path("*_R2_fastqc.html"), emit: read2_fastqc_html
    tuple val(meta), path("*_R2_fastqc.zip"), emit: read2_fastqc_zip
    tuple val(meta), path("*_value.txt"), emit: fastqc_value_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def read1 = reads[0]
    def read2 = reads[1]
    if (!read1 || !read2) {
        error "FASTQC requires two input reads, but only found: ${reads}"
    }
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Extract base names for reads
    def read1_name = read1.name.replaceAll(/\.gz$/, '').replaceAll(/\.(fastq|fq)$/, '')
    def read2_name = read2.name.replaceAll(/\.gz$/, '').replaceAll(/\.(fastq|fq)$/, '')
    
    """
    # run fastqc: 
    # --extract: uncompress output files
    fastqc \\
        --outdir . \\
        --threads ${task.cpus} \\
        --extract \\
        ${read1} \\
        ${read2} \\
        ${args}
    
    # Only rename if the output name differs from desired name
    # Tracking original behavior for now
    if [ "${read1_name}_fastqc.html" != "${prefix}_R1_fastqc.html" ]; then
        mv ${read1_name}_fastqc.html ${prefix}_R1_fastqc.html
    fi
    if [ "${read1_name}_fastqc.zip" != "${prefix}_R1_fastqc.zip" ]; then
        mv ${read1_name}_fastqc.zip ${prefix}_R1_fastqc.zip
    fi
    if [ "${read2_name}_fastqc.html" != "${prefix}_R2_fastqc.html" ]; then
        mv ${read2_name}_fastqc.html ${prefix}_R2_fastqc.html
    fi
    if [ "${read2_name}_fastqc.zip" != "${prefix}_R2_fastqc.zip" ]; then
        mv ${read2_name}_fastqc.zip ${prefix}_R2_fastqc.zip
    fi

    
    # Extract sequence counts
    read1_seqs=\$(grep "Total Sequences" ${read1_name}_fastqc/fastqc_data.txt | cut -f 2)
    read2_seqs=\$(grep "Total Sequences" ${read2_name}_fastqc/fastqc_data.txt | cut -f 2)
    
    # capture number of read pairs
    if [ "\${read1_seqs}" == "\${read2_seqs}" ]; then
        read_pairs="\${read1_seqs}"
    else
        read_pairs="Uneven pairs: R1=\${read1_seqs}, R2=\${read2_seqs}"
    fi
    
    # Write values to files for outputs
    echo "\${read1_seqs}" > READ1_SEQS_${task_prefix}_value.txt
    echo "\${read2_seqs}" > READ2_SEQS_${task_prefix}_value.txt
    echo "\${read_pairs}" > READ_PAIRS_${task_prefix}_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$(fastqc --version | sed 's/FastQC v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_R1_fastqc.html
    touch ${prefix}_R1_fastqc.zip
    touch ${prefix}_R2_fastqc.html
    touch ${prefix}_R2_fastqc.zip

    echo "1000" > READ1_SEQS_${task_prefix}_value.txt
    echo "1000" > READ2_SEQS_${task_prefix}_value.txt
    echo "1000" > READ_PAIRS_${task_prefix}_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: 0.12.1
    END_VERSIONS
    """
}