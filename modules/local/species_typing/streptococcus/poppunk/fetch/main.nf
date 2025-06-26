process POPPUNK_DATABASE {
    tag "poppunk_database"
    label "process_low"
    
    container "us-docker.pkg.dev/general-theiagen/theiagen/network-multitool:69aa4d5"

    input:
    val(db_url)
    val(ext_clusters_url)

    output:
    path("database")       , emit: database
    path("ext_clusters")   , emit: ext_clusters
    path("db_info.txt")    , emit: db_info
    path("versions.yml")   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    
    """
    # Stage PopPUNK database using helper script
    poppunk_db_helper.sh \\
        ${db_url} \\
        ${ext_clusters_url} \\
        ./database \\
        ./ext_clusters
    
    # Extract database name and info for downstream processes
    DB_NAME=\$(basename ${db_url} .tar.gz)
    echo "Database: \$DB_NAME" > db_info.txt
    echo "URL: ${db_url}" >> db_info.txt
    echo "External clusters URL: ${ext_clusters_url}" >> db_info.txt
    echo "Staged at: \$(date)" >> db_info.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        wget: \$(wget --version | head -n1 | awk '{print \$3}')
        jq: \$(jq --version | sed 's/jq-//')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p database/GPS_v9 ext_clusters
    touch database/GPS_v9/GPS_v9.h5
    touch database/GPS_v9/GPS_v9.dists.npy
    touch database/GPS_v9/GPS_v9.dists.pkl
    touch database/GPS_v9/GPS_v9_fit.npz
    touch database/GPS_v9/GPS_v9_fit.pkl
    touch database/GPS_v9/GPS_v9_graph.gt
    touch database/GPS_v9/GPS_v9_clusters.csv
    touch ext_clusters/GPS_v9_external_clusters.csv
    echo "Database: GPS_v9" > db_info.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        wget: \$(wget --version | head -n1 | awk '{print \$3}')
        jq: \$(jq --version | sed 's/jq-//')
    END_VERSIONS
    """
}