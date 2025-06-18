process NCBI_SCRUB_PE {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/theiagen/sra-human-scrubber:2.2.1"

    input:
    tuple val(meta), path(read1), path(read2)

    output:
    tuple val(meta), path("*_dehosted.fastq.gz"), emit: dehosted_reads
    tuple val(meta), path("SPOTS_REMOVED.txt"), emit: spots_removed_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # date and version control
    date | tee DATE
    
    # detect compression and define cat command
    if [[ "${read1}" == *.gz ]]; then
        echo "DEBUG: Gzipped input reads detected"
        cat_command="zcat"
    else
        cat_command="cat"
    fi
    
    # Count the number of reads in each file
    read1_count=\$(\$cat_command ${read1} | wc -l | awk '{print \$1/4}')
    read2_count=\$(\$cat_command ${read2} | wc -l | awk '{print \$1/4}')
    echo "DEBUG: Number of reads in read1: \$read1_count"
    echo "DEBUG: Number of reads in read2: \$read2_count"
    
    if [[ \$read1_count -ne \$read2_count ]]; then
        echo "ERROR: The number of reads in the two input files do not match."
        echo "ERROR: The number of reads in read1 is \$read1_count and the number of reads in read2 is \$read2_count."
        echo "ERROR: The unpaired reads will be ignored from the interleaved file..."
    fi
    
    # interleave reads
    # paste command takes 4 lines at a time and merges them into a single line with tabs
    # tr substitutes the tab separators from paste into new lines, effectively interleaving the reads and keeping the FASTQ format
    echo "DEBUG: Interleaving reads with paste..."
    paste <(\$cat_command ${read1} | paste - - - -) <(\$cat_command ${read2} | paste - - - -) | tr '\\t' '\\n' > interleaved.fastq
    
    # dehost reads
    # -x Remove spots instead of default 'N' replacement.
    # -s Input is (collated) interleaved paired-end(read) file AND you wish both reads masked or removed.
    echo "DEBUG: Running HRRT..."
    echo "DEBUG: /opt/scrubber/scripts/scrub.sh -p ${task.cpus} -x -s -i interleaved.fastq"
    /opt/scrubber/scripts/scrub.sh -p ${task.cpus} -x -s -i interleaved.fastq > STDOUT 2> STDERR
    
    # capture the number of spots removed by fetching the first item on the last line of stderr
    spots_removed=\$(cat STDERR | tail -n1 | awk -F" " '{print \$1}')
    echo "\$spots_removed" > SPOTS_REMOVED.txt
    echo "DEBUG: Human spots removed: \$spots_removed"
    
    # split interleaved reads and compress files
    # paste takes 8 lines at a time and merges them into a single line with tabs
    # grouping each pair of reads into one line
    echo "DEBUG: Splitting interleaved dehosted reads..."
    paste - - - - - - - - < interleaved.fastq.clean \\
        | tee >(cut -f 1-4 | tr '\\t' '\\n' | gzip > ${prefix}_R1_dehosted.fastq.gz) \\
        | cut -f 5-8 | tr '\\t' '\\n' | gzip > ${prefix}_R2_dehosted.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-scrubber: \$(echo "2.2.1")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_R1_dehosted.fastq.gz
    touch ${prefix}_R2_dehosted.fastq.gz
    echo "0" > SPOTS_REMOVED.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-scrubber: 2.2.1
    END_VERSIONS
    """
}