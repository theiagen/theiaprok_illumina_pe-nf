process AMR_SEARCH {
    tag "$meta.id" 
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/theiagen/amrsearch:0.2.1"
    // The AMR Search tool is run with Java, so we need to set the entrypoint to an empty string
    // to avoid Nextflow trying to run the Java command directly.
    // This is a workaround for the issue where Nextflow tries to run the Java command directly
    containerOptions "--entrypoint=''"
   
    input:
    tuple val(meta), path(assembly_fasta), val(species)

    output:
    tuple val(meta), path("*_amr_results.csv"), emit: amr_results_csv, optional: true
    tuple val(meta), path("*_amr_results.pdf"), emit: amr_results_pdf, optional: true
    tuple val(meta), path("*_paarsnp_results.jsn"), emit: amr_search_json_output, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def assembly_name = assembly_fasta.getName()
    def taxon_code_map = [
            "Neisseria gonorrhoeae": "485",
            "Staphylococcus aureus": "1280", 
            "Typhi": "90370",
            "Salmonella typhi": "90370",
            "Streptococcus pneumoniae": "1313",
            "Klebsiella": "570",
            "Klebsiella pneumoniae": "573",
            "Candida auris": "498019",
            "Candidozyma auris": "498019",
            "Vibrio cholerae": "666"
    ]
    def taxon_code = taxon_code_map.containsKey(species) ? taxon_code_map[species] : "unknown"

    """
    if [[ "${taxon_code}" != "unknown" ]]; then
        # Extract base name without path or extension
        input_base=\$(basename "${assembly_name}")
        input_base=\${input_base%.*}
        echo "DEBUG: input_base = \$input_base"

        # Run the tool - using explicit paths to avoid interpolation issues
        java -jar /paarsnp/paarsnp.jar -i ${assembly_fasta} -s ${taxon_code}

        # Move the output file from the input directory to the working directory  
        mv "./\${input_base}_paarsnp.jsn" "./${prefix}_paarsnp_results.jsn"

        # Script housed within the image
        python3 /scripts/parse_amr_json.py \\
            "./${prefix}_paarsnp_results.jsn" \\
            "${prefix}"
    else
        echo "No AMR Search performed for species: ${species} (Taxon code: ${taxon_code})"
    fi
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