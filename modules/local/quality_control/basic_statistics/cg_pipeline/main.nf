process CG_PIPELINE {
    tag "$meta.id"
    label 'process_single'

    container "us-docker.pkg.dev/general-theiagen/staphb/lyveset:1.1.4f"

    input:
    tuple val(meta), path(reads)
    val genome_length
    val cg_pipe_opts

    output:
    tuple val(meta), path('*_readMetrics.tsv'), emit: cg_pipeline_report
    tuple val(meta), path('DATE.txt'), emit: pipeline_date
    tuple val(meta), path('R1_MEAN_Q.txt'), emit: r1_mean_q
    tuple val(meta), path('R2_MEAN_Q.txt'), emit: r2_mean_q
    tuple val(meta), path('COMBINED_MEAN_Q.txt'), emit: combined_mean_q
    tuple val(meta), path('R1_MEAN_LENGTH.txt'), emit: r1_mean_readlength
    tuple val(meta), path('R2_MEAN_LENGTH.txt'), emit: r2_mean_readlength
    tuple val(meta), path('COMBINED_MEAN_LENGTH.txt'), emit: combined_mean_readlength
    tuple val(meta), path('EST_COVERAGE.txt'), emit: est_coverage
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read1 = reads[0]
    def read2 = reads[1]
    def pipe_opts = cg_pipe_opts ?: "--fast"

    """
    # date and version control
    date | tee DATE.txt

    run_assembly_readMetrics.pl ${pipe_opts} ${read1} ${read2} -e ${genome_length} ${args} > ${prefix}_readMetrics.tsv

    # repeat for concatenated read file
    # run_assembly_readMetrics.pl extension awareness    
    if [[ "${read1}" == *".gz" ]] ; then
      extension=".gz"
    else
      extension=""
    fi
    
    cat ${read1} ${read2} > ${prefix}_concat.fastq\${extension}
    run_assembly_readMetrics.pl ${pipe_opts} ${prefix}_concat.fastq\${extension} -e ${genome_length} > ${prefix}_concat_readMetrics.tsv
    
    cg_pipeline_parser.py --prefix ${prefix} \\
        --read1 "${read1}" \\
        --metrics "${prefix}_readMetrics.tsv" \\
        --concat "${prefix}_concat_readMetrics.tsv" \\

    # R2_MEAN_Q to make SE workflow work otherwise read_float fails
    if [[ ! -f R2_MEAN_Q.txt ]] ; then
      echo "0.0" > R2_MEAN_Q.txt
    fi
    # same for R2_MEAN_LENGTH
    if [[ ! -f R2_MEAN_LENGTH.txt ]] ; then
      echo "0.0" > R2_MEAN_LENGTH.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | cut -d' ' -f2)
        cg_pipeline: staphb/lyveset:1.1.4f
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "na" > "${prefix}_readMetrics.tsv"
    echo "na" > "DATE.txt"
    echo "na" > "R1_MEAN_Q.txt"
    echo "na" > "R2_MEAN_Q.txt"
    echo "na" > "COMBINED_MEAN_Q.txt"
    echo "na" > "R1_MEAN_LENGTH.txt"
    echo "na" > "R2_MEAN_LENGTH.txt"
    echo "na" > "COMBINED_MEAN_LENGTH.txt"
    echo "na" > "EST_COVERAGE.txt"
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | cut -d' ' -f2)
        cg_pipeline: staphb/lyveset:1.1.4f
    END_VERSIONS
    """
}