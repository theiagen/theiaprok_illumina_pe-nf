process SONNEITYPER {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/mykrobe:0.12.1-sonneityping"

    input:
    tuple val(meta), path(reads)
    val ont_data

    output:
    tuple val(meta), path("*.mykrobe.csv"), optional: true, emit: mykrobe_report_csv
    tuple val(meta), path("*.mykrobe.json"), optional: true, emit: mykrobe_report_json
    tuple val(meta), path("*.sonneityping.tsv"), optional: true, emit: sonneityping_final_report
    tuple val(meta), path("SPECIES.txt"), emit: sonneityping_species
    tuple val(meta), path("FINAL_GENOTYPE.txt"), emit: sonnietyping_final_genotype
    tuple val(meta), path("GENOTYPE_NAME.txt"), emit: sonneityping_genotype_name
    tuple val(meta), path("CONFIDENCE.txt"), emit: genotype_confidence
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ont_flag = ont_data ? "--ont" : ""
    def reads_input = reads.collect{ it.toString() }.join(' ')
    
    """
    # Print and save versions
    mykrobe --version | sed 's|mykrobe v||g' | tee MYKROBE_VERSION.txt
    
    # Run Mykrobe on the input read data
    mykrobe predict \\
        -t ${task.cpus} \\
        --sample ${prefix} \\
        --species sonnei \\
        --format json_and_csv \\
        --out ${prefix}.mykrobe \\
        ${ont_flag} \\
        --seq ${reads_input} \\
        ${args}
    
    # use sonneityping script to produce final TSV; alleles.txt is required input for human-readable genotype names
    python /sonneityping/parse_mykrobe_predict.py \\
        --jsons ${prefix}.mykrobe.json \\
        --alleles /sonneityping/alleles.txt \\
        --prefix ${prefix}.sonneityping
    
    if [ -f ${prefix}.sonneityping_predictResults.tsv ]; then
        echo "DEBUG: sonneityping produced expected output file"
        # rename output TSV to something prettier
        mv -v ${prefix}.sonneityping_predictResults.tsv ${prefix}.sonneityping.tsv

        # Parse the output files to create final reports
        sonneityper_parser.py --sonnei_tsv ${prefix}.sonneityping.tsv
    else 
        echo "Error: sonneityping did not produce expected output file. Check mykrobe logs."
        touch SPECIES.txt
        touch FINAL_GENOTYPE.txt
        touch GENOTYPE_NAME.txt
        touch CONFIDENCE.txt
    fi
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mykrobe: \$(mykrobe --version | sed 's|mykrobe v||g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.mykrobe.csv
    touch ${prefix}.mykrobe.json
    touch ${prefix}.sonneityping.tsv
    touch SPECIES.txt
    touch FINAL_GENOTYPE.txt
    touch GENOTYPE_NAME.txt
    touch CONFIDENCE.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       mykrobe: \$(mykrobe --version | sed 's|mykrobe v||g')
    END_VERSIONS
    """
}