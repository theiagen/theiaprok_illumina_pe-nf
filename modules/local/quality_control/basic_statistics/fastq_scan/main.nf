process FASTQ_SCAN_PE {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/fastq-scan:1.0.1--h4ac6f70_3"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_R1_fastq-scan.json"), emit: read1_fastq_scan_json
    tuple val(meta), path("*_R2_fastq-scan.json"), emit: read2_fastq_scan_json
    tuple val(meta), path("READ1_SEQS"), emit: read1_seq
    tuple val(meta), path("READ2_SEQS"), emit: read2_seq
    tuple val(meta), path("READ_PAIRS"), emit: read_pairs
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def read1 = reads[0]
    def read2 = reads[1]
    if (!read1 || !read2) {
        error "FASTQ_SCAN_PE requires two input reads, but only found: ${reads}"
    }
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # exit task in case anything fails in one-liners or variables are unset
    set -euo pipefail
    
    # set cat command based on compression
    if [[ "${read1}" == *".gz" ]] ; then
        cat_reads="zcat"
    else
        cat_reads="cat"
    fi
    
    # capture forward read stats
    echo "DEBUG: running fastq-scan on \$(basename ${read1})"
    \${cat_reads} ${read1} | fastq-scan | tee ${prefix}_R1_fastq-scan.json
    
    # using jq to extract read count
    read1_seqs=\$(jq .qc_stats.read_total ${prefix}_R1_fastq-scan.json)
    echo "DEBUG: number of reads in \$(basename ${read1}): \${read1_seqs}"
    echo
    
    # capture reverse read stats
    echo "DEBUG: running fastq-scan on \$(basename ${read2})"
    \${cat_reads} ${read2} | fastq-scan | tee ${prefix}_R2_fastq-scan.json
    
    # using jq to extract read count
    read2_seqs=\$(jq .qc_stats.read_total ${prefix}_R2_fastq-scan.json)
    echo "DEBUG: number of reads in \$(basename ${read2}): \${read2_seqs}"
    
    # capture number of read pairs
    if [ "\${read1_seqs}" == "\${read2_seqs}" ]; then
        read_pairs="\${read1_seqs}"
    else
        read_pairs="Uneven pairs: R1=\${read1_seqs}, R2=\${read2_seqs}"
    fi
    
    echo "DEBUG: number of read pairs: \${read_pairs}"
    
    # Set environment variables for outputs
    READ1_SEQS="\$read1_seqs"
    READ2_SEQS="\$read2_seqs"
    READ_PAIRS="\$read_pairs"

    # Write read counts to files
    echo "\$READ1_SEQS" > READ1_SEQS
    echo "\$READ2_SEQS" > READ2_SEQS
    echo "\$READ_PAIRS" > READ_PAIRS

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq-scan: \$(fastq-scan -v 2>&1 | sed 's/fastq-scan //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo '{"qc_stats":{"read_total":1000}}' > ${prefix}_R1_fastq-scan.json
    echo '{"qc_stats":{"read_total":1000}}' > ${prefix}_R2_fastq-scan.json
    
    READ1_SEQS="1000"
    READ2_SEQS="1000"
    READ_PAIRS="1000"

    echo "\$READ1_SEQS" > READ1_SEQS
    echo "\$READ2_SEQS" > READ2_SEQS
    echo "\$READ_PAIRS" > READ_PAIRS

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq-scan: 1.0.1
    END_VERSIONS
    """
}