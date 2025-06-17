process CHECK_READS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container = 'us-docker.pkg.dev/general-theiagen/bactopia/gather_samples:2.0.2' 

    input:
    tuple val(meta), path(read1), path(read2)
    val min_reads
    val min_basepairs
    val min_genome_length
    val max_genome_length
    val min_coverage
    val min_proportion
    val workflow_series
    val expected_genome_length

    output:
    tuple val(meta), path("*_read_screen.tsv"), emit: read_screen_tsv
    tuple val(meta), env(READ_SCREEN_FLAG), emit: read_screen
    tuple val(meta), env(EST_GENOME_LENGTH), emit: est_genome_length
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def workflow_arg = workflow_series ?: "theiaprok"
    def expected_length = expected_genome_length ?: ""
    
    """
    # just in case anything fails, throw an error
    set -euo pipefail

    # populate column headers for metrics and init failure log
    metrics_headers="read1_count\\tread2_count\\tread_bp\\test_genome_length"
    fail_log=""

    # initialize estimated genome length
    estimated_genome_length=0
    
    # set cat command based on compression
    if [[ "${read1}" == *".gz" ]] ; then
        cat_reads="zcat"
    else
        cat_reads="cat"
    fi

    # check one: number of reads
    read1_num=\$(\${cat_reads} ${read1} | fastq-scan | grep 'read_total' | sed 's/[^0-9]*\\([0-9]\\+\\).*/\\1/')
    read2_num=\$(\${cat_reads} ${read2} | fastq-scan | grep 'read_total' | sed 's/[^0-9]*\\([0-9]\\+\\).*/\\1/')
    echo "DEBUG: Number of reads in R1: \${read1_num}"
    echo "DEBUG: Number of reads in R2: \${read2_num}"

    reads_total=\$(expr \$read1_num + \$read2_num)
    echo "DEBUG: Number of reads total in R1 and R2: \${reads_total}"

    if [ "\${reads_total}" -le "${min_reads}" ]; then
        fail_log+="; the total number of reads is below the minimum of ${min_reads}"
    fi

    # count number of basepairs
    # using fastq-scan to count the number of basepairs in each fastq
    read1_bp=\$(eval "\${cat_reads} ${read1}" | fastq-scan | grep 'total_bp' | sed 's/[^0-9]*\\([0-9]\\+\\).*/\\1/')
    read2_bp=\$(eval "\${cat_reads} ${read2}" | fastq-scan | grep 'total_bp' | sed 's/[^0-9]*\\([0-9]\\+\\).*/\\1/')
    echo "DEBUG: Number of basepairs in R1: \$read1_bp"
    echo "DEBUG: Number of basepairs in R2: \$read2_bp"

    # set proportion variables for easy comparison
    # removing the , 2) to make these integers instead of floats
    percent_read1=\$(python3 -c "print(round((\$read1_bp / (\$read1_bp + \$read2_bp))*100))")
    percent_read2=\$(python3 -c "print(round((\$read2_bp / (\$read1_bp + \$read2_bp))*100))")

    if [ "\$percent_read1" -lt "${min_proportion}" ] ; then
        fail_log+="; more than ${min_proportion} percent of the total sequence is found in R2 (BP: \$read2_bp; PERCENT: \$percent_read2) compared to R1 (BP: \$read1_bp; PERCENT: \$percent_read1)"
    fi
    if [ "\$percent_read2" -lt "${min_proportion}" ] ; then
        fail_log+="; more than ${min_proportion} percent of the total sequence is found in R1 (BP: \$read1_bp; PERCENT: \$percent_read1) compared to R2 (BP: \$read2_bp; PERCENT: \$percent_read2)"
    fi

    # check total number of basepairs 
    bp_total=\$(expr \$read1_bp + \$read2_bp)
    if [ "\$bp_total" -le "${min_basepairs}" ]; then
        fail_log+="; the number of basepairs (\${bp_total}) is below the minimum of ${min_basepairs}"
    fi

    #checks four and five: estimated genome length and coverage
    # estimate genome length if theiaprok AND expected_genome_length was not provided
    if ( [ "${workflow_arg}" == "theiaprok" ] || [ "${workflow_arg}" == "theiaeuk" ] ) && [[ -z "${expected_length}" ]]; then
        # First Pass; assuming average depth
        mash sketch -o test -k 31 -m 3 -r ${read1} ${read2} > mash-output.txt 2>&1
        grep "Estimated genome size:" mash-output.txt | \\
            awk '{if(\$4){printf("%5.0f\\n", \$4)}} END {if (!NR) print "0"}' > genome_length_output
        grep "Estimated coverage:" mash-output.txt | \\
            awk '{if(\$3){printf("%d", \$3)}} END {if (!NR) print "0"}' > coverage_output
        rm -rf test.msh
        rm -rf mash-output.txt
        estimated_genome_length=\$(head -n1 genome_length_output)
        estimated_coverage=\$(head -n1 coverage_output)

        # Check if second pass is needed in theiaprok
        if [ "${workflow_arg}" == "theiaprok" ]; then
            if [ \${estimated_genome_length} -gt "${max_genome_length}" ] || [ \${estimated_genome_length} -lt "${min_genome_length}" ] ; then
                # Probably high coverage, try increasing number of kmer copies to 10
                M="-m 10"
                if [ \${estimated_genome_length} -lt "${min_genome_length}" ]; then
                    # Probably low coverage, try decreasing the number of kmer copies to 1
                    M="-m 1"
                fi
                mash sketch -o test -k 31 \${M} -r ${read1} ${read2} > mash-output.txt 2>&1
                grep "Estimated genome size:" mash-output.txt | \\
                    awk '{if(\$4){printf("%5.0f\\n", \$4)}} END {if (!NR) print "0"}' > genome_length_output
                grep "Estimated coverage:" mash-output.txt | \\
                    awk '{if(\$3){printf("%d", \$3)}} END {if (!NR) print "0"}' > coverage_output
                rm -rf test.msh
                rm -rf mash-output.txt

                estimated_genome_length=\$(head -n1 genome_length_output)
                estimated_coverage=\$(head -n1 coverage_output)
            fi
        fi
        
    # estimate coverage if theiacov OR expected_genome_length was provided
    elif [ "${workflow_arg}" == "theiacov" ] || [ "${expected_length}" ]; then
        if [ "${expected_length}" ]; then
            estimated_genome_length=${expected_length} # use user-provided expected_genome_length
        fi

        # coverage is calculated here by N/G where N is number of bases, and G is genome length
        # this will nearly always be an overestimation
        if [ \${estimated_genome_length} -ne 0 ]; then # prevent divided by zero errors
            estimated_coverage=\$(python3 -c "print(round((\$read1_bp+\$read2_bp)/\$estimated_genome_length))")
        else # they provided 0 for estimated_genome_length, nice
            estimated_coverage=0
        fi
    else 
        # workflow series was not provided or no est genome length was provided; default to fail
        estimated_genome_length=0
        estimated_coverage=0
    fi

    # Check if estimated genome length is within bounds
    if [ "\${estimated_genome_length}" -ge "${max_genome_length}" ] && ( [ "${workflow_arg}" == "theiaprok" ] || [ "${workflow_arg}" == "theiaeuk" ] ) ; then
        fail_log+="; the estimated genome length (\${estimated_genome_length}) is larger than the maximum of ${max_genome_length} bps"
    elif [ "\${estimated_genome_length}" -le "${min_genome_length}" ] && ( [ "${workflow_arg}" == "theiaprok" ] || [ "${workflow_arg}" == "theiaeuk" ] ) ; then
        fail_log+="; the estimated genome length (\${estimated_genome_length}) is smaller than the minimum of ${min_genome_length} bps"
    fi
    if [ "\${estimated_coverage}" -lt "${min_coverage}" ] ; then
        fail_log+="; the estimated coverage (\${estimated_coverage}) is less than the minimum of ${min_coverage}x"
    else
        echo "DEBUG: estimated_genome_length: \${estimated_genome_length}" 
    fi 

    # populate metrics values
    metrics="\${read1_num}\t\${read2_num}\t\${bp_total}\t\${estimated_genome_length}"

    # finish populating failure log
    if [ -z "\$fail_log" ]; then
        fail_log="PASS"
    else
        fail_log="FAIL\${fail_log}"
    fi

    echo -e \${metrics_headers} > ${prefix}_read_screen.tsv
    echo -e "\${metrics}" >> ${prefix}_read_screen.tsv
    
    # Set environment variables for outputs
    READ_SCREEN_FLAG="\$fail_log"
    EST_GENOME_LENGTH="\$estimated_genome_length"


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq-scan: \$(fastq-scan -v 2>&1 | sed 's/fastq-scan //')
        mash: \$(mash --version 2>&1 | sed 's/.*Mash //' | sed 's/ .*//')
        python: \$(python3 --version | sed 's/Python //')
END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo -e "read1_count\\tread2_count\\tread_bp\\test_genome_length\\n1000\\t1000\\t300000\\t3000000" > ${prefix}_read_screen.tsv
    
    READ_SCREEN_FLAG="PASS"
    EST_GENOME_LENGTH="3000000"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq-scan: 1.0.1
        mash: 2.3
        python: 3.8.0
    END_VERSIONS
    """
}