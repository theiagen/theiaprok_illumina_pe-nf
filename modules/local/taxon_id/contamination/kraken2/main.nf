process KRAKEN2_THEIACOV {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/kraken2:2.1.2-no-db"

    input:
    tuple val(meta), path(read1), path(read2)
    path kraken2_db
    val target_organism

    output:
    tuple val(meta), path("*_kraken2_report.txt"), emit: kraken_report
    tuple val(meta), path("*.classifiedreads.txt.gz"), emit: kraken2_classified_report
    tuple val(meta), path("PERCENT_HUMAN.txt"), emit: percent_human_file
    tuple val(meta), path("PERCENT_SC2.txt"), emit: percent_sc2_file
    tuple val(meta), path("PERCENT_TARGET_ORGANISM.txt"), emit: percent_target_organism_file
    tuple val(meta), val(target_organism), emit: kraken_target_organism
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def target_org = target_organism ?: ""
    def reads_input = read2 ? "${read1} ${read2}" : "${read1}"
    def mode = read2 ? "--paired" : ""
    def compression = read1.name.endsWith('.gz') ? "--gzip-compressed" : ""
    
    """
    # date and version control
    date | tee DATE
    
    # Decompress the Kraken2 database
    mkdir db
    tar -C ./db/ -xzvf ${kraken2_db}
    
    echo "Mode: ${mode}"
    echo "Compression: ${compression}"
    
    # Run Kraken2
    kraken2 ${mode} ${compression} \\
        --threads ${task.cpus} \\
        --db ./db/ \\
        ${reads_input} \\
        --report ${prefix}_kraken2_report.txt \\
        --output ${prefix}.classifiedreads.txt
    
    # Compress classified reads output
    gzip ${prefix}.classifiedreads.txt
    
    # capture human percentage
    percentage_human=\$(grep "Homo sapiens" ${prefix}_kraken2_report.txt | cut -f 1)
    if [ -z "\$percentage_human" ] ; then percentage_human="0" ; fi
    echo "\$percentage_human" > PERCENT_HUMAN.txt
    echo "DEBUG: Human percentage: \$percentage_human"
    
    # capture target org percentage
    if [ -n "${target_org}" ]; then
        echo "Target org designated: ${target_org}"
        # if target organism is sc2, report it in a special legacy column called PERCENT_SC2
        if [[ "${target_org}" == "Severe acute respiratory syndrome coronavirus 2" ]]; then
            percentage_sc2=\$(grep "Severe acute respiratory syndrome coronavirus 2" ${prefix}_kraken2_report.txt | cut -f1 )
            percent_target_organism=""
            if [ -z "\$percentage_sc2" ] ; then percentage_sc2="0" ; fi
            echo "DEBUG: SC2 percentage: \$percentage_sc2"
        else
            percentage_sc2="" 
            percent_target_organism=\$(grep "${target_org}" ${prefix}_kraken2_report.txt | cut -f1 | head -n1 )
            if [ -z "\$percent_target_organism" ] ; then percent_target_organism="0" ; fi
            echo "DEBUG: Target organism percentage: \$percent_target_organism"
        fi
    else
        percent_target_organism=""
        percentage_sc2=""
        echo "DEBUG: No target organism specified"
    fi
    
    echo "\$percentage_sc2" > PERCENT_SC2.txt
    echo "\$percent_target_organism" > PERCENT_TARGET_ORGANISM.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version | head -n1 | sed 's/Kraken version //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_kraken2_report.txt
    touch ${prefix}.classifiedreads.txt.gz
    echo "0.0" > PERCENT_HUMAN.txt
    echo "0.0" > PERCENT_SC2.txt
    echo "0.0" > PERCENT_TARGET_ORGANISM.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: 2.1.2
    END_VERSIONS
    """
}