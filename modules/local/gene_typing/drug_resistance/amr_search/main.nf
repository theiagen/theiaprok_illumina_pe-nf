process AMR_SEARCH {
    tag "$meta.id" 
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/theiagen/amrsearch:0.2.1"
    // The AMR Search tool is run with Java, so we need to set the entrypoint to an empty string
    // to avoid Nextflow trying to run the Java command directly.
    // This is a workaround for the issue where Nextflow tries to run the Java command directly
    containerOptions "--entrypoint=''"

    input:
    tuple val(meta), path(assembly_fasta)
    val amr_search_database 

    output:
    tuple val(meta), path("*_amr_results.csv"), emit: amr_results_csv
    tuple val(meta), path("*_amr_results.pdf"), emit: amr_results_pdf
    tuple val(meta), path("*_paarsnp_results.jsn"), emit: amr_search_json_output
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database = amr_search_database ?: "485"
    def assembly_name = assembly_fasta.getName()
    
    """
    # Extract base name without path or extension
    input_base=\$(basename "${assembly_name}")
    input_base=\${input_base%.*}
    echo "DEBUG: input_base = \$input_base"

    # Run the tool - using explicit paths to avoid interpolation issues
    java -jar /paarsnp/paarsnp.jar -i ${assembly_fasta} -s ${database}

    # Move the output file from the input directory to the working directory  
    mv "./\${input_base}_paarsnp.jsn" "./${prefix}_paarsnp_results.jsn"

    # Script housed within the image
    python3 /scripts/parse_amr_json.py \\
        "./${prefix}_paarsnp_results.jsn" \\
        "${prefix}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrsearch: \$(cat output_amr_version.txt)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}_amr_results.csv"
    touch "${prefix}_amr_results.pdf" 
    touch "${prefix}_paarsnp_results.jsn"
    echo "0.2.1" > output_amr_version.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrsearch: \$(cat output_amr_version.txt)
    END_VERSIONS
    """
}