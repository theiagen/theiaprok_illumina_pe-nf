process KMERFINDER_BACTERIA {
    tag "$meta.id"
    label 'process_high_memory'

    container "us-docker.pkg.dev/general-theiagen/biocontainers/kmerfinder:3.0.2--hdfd78af_0"

    input:
    tuple val(meta), path(assembly)
    path kmerfinder_db

    output:
    tuple val(meta), path("*_kmerfinder.tsv"), emit: kmerfinder_results_tsv
    tuple val(meta), path("TOP_HIT"),           emit: kmerfinder_top_hit
    tuple val(meta), path("QC_METRIC"),         emit: kmerfinder_query_coverage
    tuple val(meta), path("TEMPLATE_COVERAGE"), emit: kmerfinder_template_coverage
    tuple val(meta), path("DATABASE"),          emit: kmerfinder_database
    path("versions.yml"), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    
    """
    # Decompress the kmerfinder bacterial database
    mkdir db
    tar -C ./db/ -xzvf ${kmerfinder_db}  
    ls ./db
    
    # Run kmerfinder
    kmerfinder.py \\
        -db ./db/bacteria/bacteria.ATG \\
        -tax ./db/bacteria/bacteria.tax \\
        -i ${assembly} \\
        -o ${prefix} \\
        ${args} 

    # parse outputs
    if [ ! -f ${prefix}/results.txt ]; then
      PF="No hit detected in database"
      QC="No hit detected in database"
      TC="No hit detected in database"
    else
      PF="\$(cat ${prefix}/results.txt | head -n 2 | tail -n 1 | cut -f 19)"
      QC="\$(cat ${prefix}/results.txt | head -n 2 | tail -n 1 | cut -f 6)"
      TC="\$(cat ${prefix}/results.txt | head -n 2 | tail -n 1 | cut -f 7)"
        # String is empty or just contains the header
        if [ "\$PF" == "" ] || [ "\$PF" == "Species" ]; then
          PF="No hit detected in database"
          QC="No hit detected in database"
          TC="No hit detected in database"
        fi
      mv -v ${prefix}/results.txt ${prefix}_kmerfinder.tsv
    fi
    echo \$PF | tee TOP_HIT
    echo \$QC | tee QC_METRIC
    echo \$TC | tee TEMPLATE_COVERAGE

    # extract database name
    DB=\$(basename ${kmerfinder_db} | sed 's/\\.tar\\.gz\$//')
    echo \$DB | tee DATABASE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmerfinder: kmerfinder:3.0.2--hdfd78af_0
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "na" > "${prefix}_kmerfinder.tsv"
    echo "na" > "TOP_HIT"
    echo "na" > "QC_METRIC"
    echo "na" > "TEMPLATE_COVERAGE"
    echo "na" > "DATABASE"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmerfinder: kmerfinder:3.0.2--hdfd78af_0
    END_VERSIONS
    """
}