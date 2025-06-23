process KRAKEN2 {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/kraken2:2.1.2-no-db"

    input:
    tuple val(meta), path(reads)
    path kraken2_db
    val kraken2_args
    val classified_out
    val unclassified_out

    output:
    tuple val(meta), path("*.report.txt"), emit: kraken2_report
    tuple val(meta), path("*.classifiedreads.txt.gz"), emit: kraken2_classified_report
    tuple val(meta), path("*.unclassified_*.fastq.gz"), emit: kraken2_unclassified_reads
    tuple val(meta), path("*.classified_*.fastq.gz"), emit: kraken2_classified_reads
    tuple val(meta), path("PERCENT_HUMAN.txt"), emit: kraken2_percent_human_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: kraken2_args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    def classified_output = classified_out ?: "classified#.fastq"
    def unclassified_output = unclassified_out ?: "unclassified#.fastq"
    def read1 = reads[0]
    def read2 = reads.size() > 1 ? reads[1] : null
    def reads_input = read2 ? "${read1} ${read2}" : "${read1}"
    def mode = read2 ? "--paired" : ""
    def compression = read1.name.endsWith('.gz') ? "--gzip-compressed" : ""
    
    """
    set -euo pipefail

    date | tee DATE
    
    # Decompress the Kraken2 database
    mkdir db
    tar -C ./db/ --strip-components=1 -xzf ${kraken2_db}
    
    echo "Reads are paired: ${read2 ? 'true' : 'false'}"
    echo "Reads are compressed: ${read1.name.endsWith('.gz') ? 'true' : 'false'}"
    
    # Run Kraken2
    echo "Running Kraken2..."
    kraken2 ${mode} ${compression} \\
        --db ./db/ \\
        --threads ${task.cpus} \\
        --report ${prefix}.report.txt \\
        --unclassified-out ${prefix}.${unclassified_output} \\
        --classified-out ${prefix}.${classified_output} \\
        --output ${prefix}.classifiedreads.txt \\
        ${args} \\
        ${reads_input}
    
    # Compress output files
    gzip *.fastq
    gzip ${prefix}.classifiedreads.txt
    
    # Report percentage of human reads
    percentage_human=\$(grep "Homo sapiens" ${prefix}.report.txt | cut -f 1 || echo "0" )
    echo "\$percentage_human" > PERCENT_HUMAN.txt
    echo "DEBUG: Human percentage: \$percentage_human"
    
    # rename classified and unclassified read files if single-end
    if [ -e "${prefix}.classified#.fastq.gz" ]; then
        mv "${prefix}.classified#.fastq.gz" ${prefix}.classified_1.fastq.gz
    fi
    if [ -e "${prefix}.unclassified#.fastq.gz" ]; then
        mv "${prefix}.unclassified#.fastq.gz" ${prefix}.unclassified_1.fastq.gz
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1 | sed 's/^.*Kraken version //;s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.report.txt
    echo "" | gzip > ${prefix}.classifiedreads.txt.gz
    echo "" | gzip > ${prefix}.unclassified_1.fastq.gz
    echo "" | gzip > ${prefix}.classified_1.fastq.gz

    echo "0.0" > PERCENT_HUMAN.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1 | sed 's/^.*Kraken version //;s/ .*\$//')
    END_VERSIONS
    """
}