process AMR_SEARCH {
    tag "$meta.id" 
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/theiagen/amrsearch:0.2.1"

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
    # Extract base name without path or extension
    input_base=\$(basename ${assembly_fasta}})
    input_base=\${input_base%.*}
    echo "DEBUG: input_base = \${input_base}"

    # Run the tool
    java -jar /paarsnp/paarsnp.jar \
        -i ${assembly_fasta} \
        -s ${database}

    # Move the output file from the input directory to the working directory
    mv \$(dirname ${assembly_fasta})/\${input_base}_paarsnp.jsn ./${prefix}_paarsnp_results.json

    # Script housed within the image; https://github.com/theiagen/theiagen_docker_builds/tree/awh-amrsearch-image/amrsearch/0.0.20
    python3 /scripts/parse_amr_json.py \
        ./${prefix}_paarsnp_results.jsn \
        ${prefix}

      
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrsearch: \$(cat output_amr_version.txt)"
    END_VERSIONS
    """

}