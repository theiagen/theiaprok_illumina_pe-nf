process MIDAS_BUILD {
    tag "$meta.id"
    label "process_high"

    container "us-docker.pkg.dev/general-theiagen/fhcrc-microbiome/midas:v1.3.2--6"

    input:
    tuple val(meta), path(genomes_dir), path(mapfile)

    output:
    tuple val(meta), path("*.tar.gz"), emit: database
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # Build MIDAS database
    build_midas_db.py ${genomes_dir} ${mapfile} midas_database ${args}
    
    # Compress the database
    tar -czf ${prefix}_midas_database.tar.gz midas_database/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        midas: 1.3.2
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p midas_database
    touch midas_database/test_db
    tar -czf ${prefix}_midas_database.tar.gz midas_database/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        midas: 1.3.2
        python: 2.7.18
    END_VERSIONS
    """
}