process POPPUNK {
    tag "$meta.id"
    label "process_medium"

    // container "us-docker.pkg.dev/general-theiagen/staphb/poppunk:2.4.0"
    container 'community.wave.seqera.io/library/poppunk:2.4.0--e909346af4c3d6fe'

    input:
    tuple val(meta), path(assembly)
    path(gps_database)
    path(gps_external_clusters_csv)
    path(gps_db_info)

    output:
    tuple val(meta), path("GPSC.txt")                                       , emit: gps_cluster
    tuple val(meta), path("*_poppunk/*poppunk_external_clusters.csv")       , emit: external_cluster_csv, optional: true
    tuple val(meta), path("GPS_DB_NAME")                                    , emit: gps_db_version
    path "versions.yml"                                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # Create input TSV
    echo -e "${prefix}\\t${assembly}" > ${prefix}_poppunk_input.tsv
    
    
    # Determine the database name
    GPS_DB_NAME=\$(grep "^Database:" ${gps_db_info} | cut -d' ' -f2)
    echo "\${GPS_DB_NAME}" > GPS_DB_NAME

    # Run poppunk
    poppunk_assign \\
        --threads ${task.cpus} \\
        --db ${gps_database}/\${GPS_DB_NAME} \\
        --distances ${gps_database}/"\${GPS_DB_NAME}"/"\${GPS_DB_NAME}".dists \\
        --query ${prefix}_poppunk_input.tsv \\
        --output ${prefix}_poppunk \\
        --external-clustering ${gps_external_clusters_csv} \\
        ${args}
    
    # Parse output CSV for GPSC (Global Pneumococcal Sequence Cluster)
    if [ -f ${prefix}_poppunk/${prefix}_poppunk_external_clusters.csv ]; then
        cut -d ',' -f 2 ${prefix}_poppunk/${prefix}_poppunk_external_clusters.csv | tail -n 1 > GPSC.txt
        
        # If GPSC is "NA", overwrite with helpful message
        if [[ "\$(cat GPSC.txt)" == "NA" ]]; then
            echo "Potential novel GPS Cluster identified, please email globalpneumoseq@gmail.com to have novel clusters added to the database and a GPSC cluster name assigned after you have checked for low level contamination which may contribute to biased accessory distances." >> GPSC.txt
        fi
    else
        echo "poppunk failed" >> GPSC.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        poppunk: \$(poppunk --version | sed 's/poppunk //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "GPS_v6" > GPS_DB_NAME
    echo "GPSC1" > GPSC.txt
    mkdir -p ${prefix}_poppunk
    touch ${prefix}_poppunk/${prefix}_poppunk_external_clusters.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        poppunk: \$(poppunk --version | sed 's/poppunk //')
    END_VERSIONS
    """
}