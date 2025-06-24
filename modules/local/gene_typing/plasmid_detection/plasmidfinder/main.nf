process PLASMIDFINDER {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/plasmidfinder:2.1.6"

    input:
    tuple val(meta), path(assembly)
    val database
    val database_path
    val method_path
    val min_percent_coverage
    val min_percent_identity

    output:
    tuple val(meta), path("*_results.tsv"), emit: plasmidfinder_results
    tuple val(meta), path("*_seqs.fsa"), emit: plasmidfinder_seqs
    tuple val(meta), path("PLASMIDS.txt"), emit: plasmidfinder_plasmids
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database_arg = database ? "-d ${database}" : ""
    def database_path_arg = database_path ? "-p ${database_path}" : ""
    def method_path_arg = method_path ? "-mp ${method_path}" : ""
    def coverage_arg = min_percent_coverage ? "-l ${min_percent_coverage}" : ""
    def identity_arg = min_percent_identity ? "-t ${min_percent_identity}" : ""
    def VERSION = "2.1.6" // Default version, not specified by cli
    
    """
    date | tee DATE
    
    if [[ -n "${database}" ]]; then 
        echo "User database identified; ${database} will be utilized for analysis"
        plasmidfinder_db_version="${database}"
    else
        plasmidfinder_db_version="unmodified from plasmidfinder docker container"
    fi
    echo "\$plasmidfinder_db_version" > PLASMIDFINDER_DB_VERSION.txt
    
    plasmidfinder.py \\
        -i ${assembly} \\
        -x \\
        ${database_arg} \\
        ${database_path_arg} \\
        ${method_path_arg} \\
        ${coverage_arg} \\
        ${identity_arg} \\
        ${args}
    
    # parse outputs
    if [ ! -f results_tab.tsv ]; then
        PF="No plasmids detected in database"
    else
        PF="\$(tail -n +2 results_tab.tsv | uniq | cut -f 2 | sort | paste -s -d, - )"
        if [ "\$PF" == "" ]; then
            PF="No plasmids detected in database"
        fi  
    fi
    echo "\$PF" > PLASMIDS.txt
    
    # Rename output files
    if [ -f results_tab.tsv ]; then
        mv -v results_tab.tsv ${prefix}_results.tsv
    else
        touch ${prefix}_results.tsv
    fi
    
    if [ -f Hit_in_genome_seq.fsa ]; then
        mv -v Hit_in_genome_seq.fsa ${prefix}_seqs.fsa
    else
        touch ${prefix}_seqs.fsa
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plasmidfinder: ${VERSION}
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = "2.1.6" // Default version, not specified by cli
    """
    touch ${prefix}_results.tsv
    touch ${prefix}_seqs.fsa
    echo "No plasmids detected in database" > PLASMIDS.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plasmidfinder: ${VERSION}
    END_VERSIONS
    """
}