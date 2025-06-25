process SEROBA {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/seroba:1.0.2"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("SEROTYPE")                           , emit: seroba_serotype
    tuple val(meta), path("ARIBA_SEROTYPE")                     , emit: seroba_ariba_serotype
    tuple val(meta), path("ARIBA_IDENTITY")                     , emit: seroba_ariba_identity
    tuple val(meta), path("detailed_serogroup_info.txt")        , emit: seroba_details, optional: true
    path "versions.yml"                                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Ensure reads is a list, even if only one read is provided
    def input_files = reads instanceof List ? reads : [reads]
    def read1 = input_files[0]
    def read2 = input_files.size() > 1 ? input_files[1] : ""
    
    """
    # Run seroba serotyping
    # Database path will need to be changed if/when docker image is updated
    seroba runSerotyping \\
        /seroba-1.0.2/database/ \\
        ${read1} \\
        ${read2} \\
        ${prefix} \\
        ${args}
    
    # Check for serotype grouping & contamination flag
    cut -f2 ${prefix}/pred.tsv > SEROTYPE
    
    # Check for detailed serogroup information
    if [ -f ${prefix}/detailed_serogroup_info.txt ]; then 
        grep "Serotype predicted by ariba" ${prefix}/detailed_serogroup_info.txt | cut -f2 | sed 's/://' > ARIBA_SEROTYPE
        grep "assembly from ariba" ${prefix}/detailed_serogroup_info.txt | cut -f2 | sed 's/://' > ARIBA_IDENTITY
    else 
        # If the details do not exist, output blanks to ariba columns
        echo "" > ARIBA_SEROTYPE
        echo "" > ARIBA_IDENTITY
    fi

    if [ -f ${prefix}/detailed_serogroup_info.txt ]; then
        # If the detailed serogroup info file exists, copy it to the current directory
        cp -v ${prefix}/detailed_serogroup_info.txt .
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seroba: \$(seroba version | head -n1)
    END_VERSIONS
    """

    stub:
    """
    touch detailed_serogroup_info.txt
    echo "unknown" > SEROTYPE
    echo "" > ARIBA_SEROTYPE
    echo "" > ARIBA_IDENTITY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seroba: \$(seroba version | head -n1)
    END_VERSIONS
    """
}