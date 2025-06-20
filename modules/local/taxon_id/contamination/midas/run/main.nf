process MIDAS {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/fhcrc-microbiome/midas:v1.3.2--6"

    input:
    tuple val(meta), path(read1), path(read2)
    path midas_db

    output:
    tuple val(meta), path("*/species/*_species_profile.tsv"), emit: species_profile
    tuple val(meta), path("*/species/*_log.txt"), emit: log_file
    tuple val(meta), path("PRIMARY_GENUS.txt"), emit: primary_genus_file
    tuple val(meta), path("SECONDARY_GENUS.txt"), emit: secondary_genus_file
    tuple val(meta), path("SECONDARY_GENUS_ABUNDANCE.txt"), emit: secondary_genus_abundance_file
    tuple val(meta), path("SECONDARY_GENUS_COVERAGE.txt"), emit: secondary_genus_coverage_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read2_arg = read2 ? "-2 ${read2}" : ""
    
    """
    date | tee DATE
    
    # Decompress the Midas database
    mkdir db
    echo "Decompressing Midas database. Please be patient, this may take a few minutes."
    tar -C ./db/ --strip-components=1 -xzf ${midas_db}
    
    # Run run_midas.py
    run_midas.py species ${prefix} \\
        -1 ${read1} \\
        ${read2_arg} \\
        -d db/ \\
        -t ${task.cpus} \\
        ${args}
    
    # rename output files
    mv -v ${prefix}/species/species_profile.txt ${prefix}/species/${prefix}_species_profile.tsv
    mv -v ${prefix}/species/log.txt ${prefix}/species/${prefix}_log.txt

    parse_midas_output.py ${prefix}/species/${prefix}_species_profile.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        midas: 1.3.2
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}/species
    touch ${prefix}/species/${prefix}_species_profile.tsv
    touch ${prefix}/species/${prefix}_log.txt
    touch PRIMARY_GENUS.txt
    touch SECONDARY_GENUS.txt
    touch SECONDARY_GENUS_ABUNDANCE.txt
    touch SECONDARY_GENUS_COVERAGE.txt
    touch versions.yml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        midas: 1.3.2
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """
}