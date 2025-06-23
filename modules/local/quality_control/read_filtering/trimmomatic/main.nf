process TRIMMOMATIC_PE {
    tag "$meta.id"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/staphb/trimmomatic:0.39"

    input:
    tuple val(meta), path(reads)
    val trimmomatic_min_length
    val trimmomatic_window_size
    val trimmomatic_quality_trim_score
    val trimmomatic_base_crop
    val trimmomatic_args

    output:
    tuple val(meta), path("*P.fastq.gz"), emit: trimmed_reads
    tuple val(meta), path("*.trim.stats.txt"), emit: trimmomatic_stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def trim_args = trimmomatic_args ?: "-phred33"
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Ensure reads are paired
    if (reads.size() != 2) {
        error "TRIMMOMATIC_PE requires exactly two reads (forward and reverse). Found: ${reads.size()} reads."
    }
    def read1 = reads[0]
    def read2 = reads[1]
    def min_length = trimmomatic_min_length ?: 75
    def window_size = trimmomatic_window_size ?: 4
    def quality_score = trimmomatic_quality_trim_score ?: 30
    def base_crop = trimmomatic_base_crop ?: ""
    
    """
    # date and version control
    date | tee DATE
    
    CROPPING_VAR=""
    # if trimmomatic base crop is defined (-n means not empty), determine average readlength of the input reads
    if [ -n "${base_crop}" ]; then
        # determine the average read length of the input reads
        read_length_r1=\$(zcat ${read1} | awk '{if(NR%4==2) {bases+=length(\$0)} } END {print bases/(NR/4)}')
        read_length_r2=\$(zcat ${read2} | awk '{if(NR%4==2) {bases+=length(\$0)} } END {print bases/(NR/4)}')
        
        # take the average of the two read lengths and remove the end base crop
        avg_readlength=\$(python3 -c "print(int(((\$read_length_r1 + \$read_length_r2) / 2) - ${base_crop}))")
        
        # HEADCROP: number of bases to remove from the start of the read
        # CROP: number of bases to KEEP, from the start of the read
        CROPPING_VAR="HEADCROP:${base_crop} CROP:\$avg_readlength"
        echo "DEBUG: Using cropping parameters: \$CROPPING_VAR"
    fi
    
    trimmomatic PE \\
        ${trim_args} \\
        -threads ${task.cpus} \\
        ${read1} ${read2} \\
        -baseout ${prefix}.fastq.gz \\
        \${CROPPING_VAR} \\
        SLIDINGWINDOW:${window_size}:${quality_score} \\
        MINLEN:${min_length} &> ${prefix}.trim.stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trimmomatic: \$(trimmomatic -version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "fwd" > ${prefix}_1P.fastq.gz
    echo "reverse" > ${prefix}_2P.fastq.gz
    echo "stats" > ${prefix}.trim.stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trimmomatic: \$(trimmomatic -version)
    END_VERSIONS
    """
}