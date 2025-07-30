process GENOTYPHI {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/mykrobe:0.11.0"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_mykrobe_genotyphi_predictResults.tsv") , emit: genotyphi_report
    tuple val(meta), path("*.mykrobe_genotyphi.json")               , emit: genotyphi_json
    tuple val(meta), path("*_value.txt")                            , emit: genotyphi_value_results
    path "versions.yml"                                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ont_data = params.genotyphi_ont_data ? '--ont' : ''
    
    // Handle single or paired reads
    def input_files = reads instanceof List ? reads : [reads]
    def read_inputs = input_files.join(' ')
    
    """
    # Print and save versions
    mykrobe --version | sed 's|mykrobe v||g' | tee MYKROBE_VERSION
    # Super ugly oneliner since "python /genotyphi/genotyphi.py --version" does NOT work due to python syntax error
    grep '__version__ =' /genotyphi/genotyphi.py | sed "s|__version__ = '||" | sed "s|'||" | tee GENOTYPHI_VERSION

    # Run Mykrobe on the input read data
    mykrobe predict \\
        -t ${task.cpus} \\
        --sample ${prefix} \\
        --species typhi \\
        --format json \\
        --out ${prefix}.mykrobe_genotyphi.json \\
        ${ont_data} \\
        --seq ${read_inputs} \\
        ${args}

    # Use genotyphi script to produce TSV
    python /genotyphi/parse_typhi_mykrobe.py \\
        --jsons ${prefix}.mykrobe_genotyphi.json \\
        --prefix ${prefix}_mykrobe_genotyphi

    # Parse output file using external script
    genotyphi_parser.py \\
        ${prefix}_mykrobe_genotyphi_predictResults.tsv
    
    mv SPECIES genotyphi_SPECIES_value.txt
    mv SPP_PERCENT genotyphi_SPP_PERCENT_value.txt
    mv FINAL_GENOTYPE genotyphi_FINAL_GENOTYPE_value.txt
    mv CONFIDENCE genotyphi_CONFIDENCE_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mykrobe: \$(mykrobe --version | sed 's|mykrobe v||g')
        genotyphi: \$(grep '__version__ =' /genotyphi/genotyphi.py | sed "s|__version__ = '||" | sed "s|'||")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_mykrobe_genotyphi_predictResults.tsv
    touch ${prefix}.mykrobe_genotyphi.json
    touch SPECIES
    touch SPP_PERCENT
    touch FINAL_GENOTYPE
    touch CONFIDENCE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mykrobe: \$(mykrobe --version | sed 's|mykrobe v||g' || echo "0.11.0")
        genotyphi: \$(grep '__version__ =' /genotyphi/genotyphi.py | sed "s|__version__ = '||" | sed "s|'||")
    END_VERSIONS
    """
}