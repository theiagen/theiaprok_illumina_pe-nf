process ABRICATE {
    tag "$meta.id"
    label "process_low"


    container "us-docker.pkg.dev/general-theiagen/staphb/abricate:1.0.1-abaum-plasmid"

    input:
    tuple val(meta), path(assembly_fasta), val(database)

    output:
    tuple val(meta), path("*_abricate_hits.tsv"), emit: abricate_results
    tuple val(meta), env(ABRICATE_GENES), emit: abricate_genes
    tuple val(meta), val(database), emit: abricate_database
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    abricate -v | tee ABRICATE_VERSION
    abricate --list
    abricate --check

    abricate \
        --db ${database} \
        ${params.min_percent_identity ? '--minid ' + params.min_percent_identity : ''} \
        ${params.min_percent_coverage ? '--mincov ' + params.min_percent_coverage : ''} \
       --threads ${task.cpus} \
        --nopath \
        ${assembly_fasta} > ${prefix}_abricate_hits.tsv

    # parse out gene names into list of strings, comma-separated, final comma at end removed by sed
    abricate_genes=\$(awk -F '\t' '{ print \$6 }' ${prefix}_abricate_hits.tsv | tail -n+2 | tr '\n' ',' | sed 's/.$//')

    # if variable for list of genes is EMPTY, write string saying it is empty to float to Terra table
    if [ -z "\${abricate_genes}" ]; then
        abricate_genes="No genes detected by ABRicate"
    fi

    # create final output strings
    ABRICATE_GENES="\${abricate_genes}"
    """

}