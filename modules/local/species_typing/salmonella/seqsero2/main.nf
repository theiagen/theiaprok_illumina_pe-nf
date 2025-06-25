process SEQSERO2 {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "us-docker.pkg.dev/general-theiagen/staphb/seqsero2:1.3.1"

    input:
    tuple val(meta), path(reads_or_assembly)

    output:
    tuple val(meta), path("*_SeqSero_result.tsv")       , emit: seqsero2_report
    tuple val(meta), path("PREDICTED_ANTIGENIC_PROFILE"), emit: seqsero_antigenic_profile
    tuple val(meta), path("PREDICTED_SEROTYPE")         , emit: seqsero_serotype
    tuple val(meta), path("CONTAMINATION")              , emit: seqser_contamination, optional: true
    tuple val(meta), path("NOTE")                       , emit: seqsero_note
    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mode = params.seqsero2_mode ?: 'a'
    // Loose determination of whether the input is reads or assembly for now
    def is_assembly = reads_or_assembly.toString().endsWith('.fasta') || 
                      reads_or_assembly.toString().endsWith('.fa') || 
                      reads_or_assembly.toString().endsWith('.fna')
    
    def input_files = reads_or_assembly instanceof List ? reads_or_assembly : [reads_or_assembly]
    def is_paired = input_files.size() == 2
    // Set parameters based on input type reads or assembly
    def data_type = is_assembly ? '4' : (is_paired ? '2' : '3')
    def analysis_mode = is_assembly ? 'k' : mode
    def max_threads = is_assembly ? '4' : task.cpus
    def input_str = input_files.join(' ')
    def contamination_mode = is_assembly ? 'assembly' : 'reads'
    
    """
    # Print and save version
    SeqSero2_package.py --version | tee VERSION

    # Run SeqSero2
    SeqSero2_package.py \\
        -p ${max_threads} \\
        -m ${analysis_mode} \\
        -t ${data_type} \\
        -n ${prefix} \\
        -d ${prefix}_seqsero2_output_dir \\
        -i ${input_str} \\
        ${args}

    # Parse the output using the external Python script
    seqsero2_parser.py \\
        ${prefix}_seqsero2_output_dir/SeqSero_result.tsv \\
        --mode ${contamination_mode}

    # Copy and rename the main report file
    cp ${prefix}_seqsero2_output_dir/SeqSero_result.tsv ${prefix}_SeqSero_result.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqsero2: \$(SeqSero2_package.py --version 2>&1 | sed 's/SeqSero2_package.py //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_SeqSero_result.tsv
    touch PREDICTED_ANTIGENIC_PROFILE
    touch PREDICTED_SEROTYPE
    touch CONTAMINATION
    touch NOTE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqsero2: \$(SeqSero2_package.py --version 2>&1 | sed 's/SeqSero2_package.py //')
    END_VERSIONS
    """
}