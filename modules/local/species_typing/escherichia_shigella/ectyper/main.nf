process ECTYPER {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/ectyper:1.0.0--pyhdfd78af_1"

    input:
    tuple val(meta), path(assembly)
    val o_min_percent_identity
    val h_min_percent_identity
    val o_min_percent_coverage
    val h_min_percent_coverage
    val verify
    val print_alleles

    output:
    tuple val(meta), path("*.tsv"), emit: ectyper_results
    tuple val(meta), path("PREDICTED_SEROTYPE.txt"), emit: ectyper_predicted_serotype_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def opid_arg = o_min_percent_identity ? o_min_percent_identity : 90
    def hpid_arg = h_min_percent_identity ? h_min_percent_identity : 95
    def opcov_arg = o_min_percent_coverage ? o_min_percent_coverage : 90
    def hpcov_arg = h_min_percent_coverage ? h_min_percent_coverage : 50
    def verify_arg = verify ? "--verify" : ""
    def alleles_arg = print_alleles ? "-s" : ""
    
    """
    ectyper \\
        -opid ${opid_arg} \\
        -hpid ${hpid_arg} \\
        -opcov ${opcov_arg} \\
        -hpcov ${hpcov_arg} \\
        ${verify_arg} \\
        ${alleles_arg} \\
        --cores ${task.cpus} \\
        --output ./ \\
        --input ${assembly} \\
        ${args}

    # Rename output file
    if [ -f output.tsv ]; then
        mv output.tsv ${prefix}.tsv
    else
        touch ${prefix}.tsv
    fi
    
    # parse ECTyper TSV - extract predicted serotype from column 5
    if [ -f ${prefix}.tsv ] && [ \$(wc -l < ${prefix}.tsv) -gt 1 ]; then
        predicted_serotype=\$(cut -f 5 ${prefix}.tsv | tail -n 1)
    else
        # If the file is empty or does not exist, set a default message
        predicted_serotype="No serotype predicted"
    fi
    echo "\$predicted_serotype" > PREDICTED_SEROTYPE.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ectyper: \$(ectyper --version 2>&1 | sed 's/.*ectyper //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    echo "No serotype predicted" > PREDICTED_SEROTYPE.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ectyper: \$(ectyper --version 2>&1 | sed 's/.*ectyper //; s/ .*\$//')
    END_VERSIONS
    """
}