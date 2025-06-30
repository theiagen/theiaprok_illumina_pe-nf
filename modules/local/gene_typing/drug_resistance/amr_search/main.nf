process AMR_SEARCH {
    tag "$meta.id" 
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/theiagen/amrsearch:0.2.1"
    containerOptions '--entrypoint=""'

    input:
    tuple val(meta), path(assembly_fasta)
    val amr_search_database 

    output:
    tuple val(meta), path("*_amr_results.csv"), emit: amr_results_csv
    tuple val(meta), path("*_amr_results.pdf"), emit: amr_results_pdf
    tuple val(meta), path("*_paarsnp_results.json"), emit: amr_search_json_output
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database = amr_search_database ?: "485"
    """
    # Unzip the assembly if necessary
    REAL_FILE=\$(readlink -f "${assembly_fasta}")
    if [[ "\${REAL_FILE}" == *.gz ]] || [[ "\$(file -b "\${REAL_FILE}")" == *"gzip"* ]] || [[ "\$(file -b --mime-type "\${REAL_FILE}")" == "application/gzip" ]]; then
        zcat "\${REAL_FILE}" > assembly.fa
    else
        ln -sf "\${REAL_FILE}" assembly.fa
    fi
    # Run the tool
    java -jar /paarsnp/paarsnp.jar \
        -i assembly.fa \
        -s ${database}

    # Move the output file from the input directory to the working directory
    ln -sf assembly_paarsnp.jsn ./${prefix}_paarsnp_results.json

    # Script housed within the image; https://github.com/theiagen/theiagen_docker_builds/tree/awh-amrsearch-image/amrsearch/0.0.20
    python3 /scripts/parse_amr_json.py \
        ./${prefix}_paarsnp_results.json \
        ${prefix}

      
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrsearch: \$(cat output_amr_version.txt)"
    END_VERSIONS
    """

}