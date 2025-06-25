process STAPHOPIASCCMEC {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/staphopia-sccmec:1.0.0--hdfd78af_0"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.staphopia-sccmec.summary.tsv") , emit: staphopia_results_tsv
    tuple val(meta), path("*.staphopia-sccmec.hamming.tsv") , emit: staphopia_hamming_distance_tsv
    tuple val(meta), path("TYPES_AND_MECA.txt")             , emit: staphopia_types_and_meca_presence
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # Run staphopia-sccmec on input assembly (hamming option OFF)
    # Outputs are true/false for each SCCmec type
    staphopia-sccmec \\
        --assembly ${assembly} \\
        ${args} \\
        > ${prefix}.staphopia-sccmec.summary.tsv
    
    # Run staphopia-sccmec on input assembly (hamming option ON)  
    # Outputs are the hamming distance; 0 is exact match
    staphopia-sccmec \\
        --hamming \\
        --assembly ${assembly} \\
        ${args} \\
        > ${prefix}.staphopia-sccmec.hamming.tsv
    
    # please excuse this ugly bash code below :)

    # parse output summary TSV for true matches
    # look for columns that contain the word "True" and print the column numbers in a list to a file col_headers.txt
    awk '{ for (i=1; i<=NF; ++i) { if (\$i ~ "True") print i } }' ${prefix}.staphopia-sccmec.summary.tsv | tee col_headers.txt

    # use column number list to print column headers (example: IV, mecA, etc.) to a file type.txt
    cat col_headers.txt | while read -r COL_NUMBER; do \
      cut -f "\$COL_NUMBER" ${prefix}.staphopia-sccmec.summary.tsv | head -n 1 >>type.txt
      echo "," >>type.txt
    done

    # remove newlines, remove trailing comma; generate output string of comma separated values
    cat type.txt | tr -d '\n' | sed 's|.\$||g' | tee TYPES_AND_MECA.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        staphopia-sccmec: \$(staphopia-sccmec --version 2>&1 | sed 's/^.*staphopia-sccmec //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.staphopia-sccmec.summary.tsv
    touch ${prefix}.staphopia-sccmec.hamming.tsv
    touch TYPES_AND_MECA.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        staphopia-sccmec: \$(staphopia-sccmec --version 2>&1 | sed 's/^.*staphopia-sccmec //')
    END_VERSIONS
    """
}