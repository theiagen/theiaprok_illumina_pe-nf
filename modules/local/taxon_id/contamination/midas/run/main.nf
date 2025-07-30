process MIDAS {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/fhcrc-microbiome/midas:v1.3.2--6"

    input:
    tuple val(meta), path(reads)
    path midas_db

    output:
    tuple val(meta), path("*/species/*_species_profile.tsv"), emit: species_profile
    tuple val(meta), path("*/species/*_log.txt"), emit: log_file
    tuple val(meta), path("*_value.txt"), emit: midas_value_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read1 = reads[0]
    def read2 = reads.size() > 1 ? reads[1] : null
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

    mv PRIMARY_GENUS.txt PRIMARY_GENUS_value.txt
    mv SECONDARY_GENUS.txt SECONDARY_GENUS_value.txt
    mv SECONDARY_GENUS_ABUNDANCE.txt SECONDARY_GENUS_ABUND_value.txt
    mv SECONDARY_GENUS_COVERAGE.txt SECONDARY_GENUS_COVER_value.txt

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
    touch PRIMARY_GENUS_value.txt
    touch SECONDARY_GENUS_value.txt
    touch SECONDARY_GENUS_ABUND_value.txt
    touch SECONDARY_GENUS_COVER_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        midas: 1.3.2
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """
}