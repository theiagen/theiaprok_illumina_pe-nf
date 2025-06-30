process BUSCO {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/ezlabgva/busco:v5.7.1_cv1"

    input:
    tuple val(meta), path(assembly)
    val eukaryote

    output:
    tuple val(meta), path("*_busco-summary.txt"), optional: true, emit: busco_report
    tuple val(meta), path("*_value.txt"), emit: busco_value_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def lineage_arg = eukaryote ? "--auto-lineage-euk" : "--auto-lineage-prok"
    
    """
    busco \\
        -i ${assembly} \\
        -c ${task.cpus} \\
        -m geno \\
        -o ${prefix} \\
        ${lineage_arg}
    
    # check for existence of output file; otherwise display a string that says the output was not created
    if [ -f ${prefix}/short_summary.specific.*.${prefix}.txt ]; then
        # grab the database version and format it according to BUSCO recommendations
        # pull line out of final specific summary file
        # cut out the database name and date it was created
        # sed is to remove extra comma and to add parentheses around the date and remove all tabs
        # finally write to a file called DATABASE
        cat ${prefix}/short_summary.specific.*.${prefix}.txt | grep "dataset is:" | cut -d' ' -f 6,9 | sed 's/,//; s/ / (/; s/\$/)/; s|[\\t]||g' | tee BUSCO_DATABASE_value.txt
        
        # extract the results string; strip off all tab and space characters; write to a file called BUSCO_RESULTS
        cat ${prefix}/short_summary.specific.*.${prefix}.txt | grep "C:" | sed 's|[\\t]||g; s| ||g' | tee BUSCO_RESULTS_value.txt
        
        # rename final output file to predictable name
        cp -v ${prefix}/short_summary.specific.*.${prefix}.txt ${prefix}_busco-summary.txt
    else
        echo "BUSCO FAILED" | tee BUSCO_RESULTS_value.txt
        echo "NA" > DATABASE_value.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(busco --version 2>&1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "bacteria_odb10 (2020-03-06)" > BUSCO_DATABASE_value.txt
    echo "C:95.5%[S:94.1%,D:1.4%],F:2.1%,M:2.4%,n:124" > BUSCO_RESULTS_value.txt
    touch ${prefix}_busco-summary.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(busco --version 2>&1)
    END_VERSIONS
    """
}