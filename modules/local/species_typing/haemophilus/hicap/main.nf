process HICAP {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/hicap:1.0.3--py_0"

    input:
    tuple val(meta), path(assembly)
    val min_gene_percent_coverage
    val min_gene_percent_identity
    val min_broken_gene_percent_identity
    val broken_gene_length

    output:
    tuple val(meta), path("*.hicap.tsv")      , emit: hicap_results_tsv
    tuple val(meta), path("*_value.txt")      , emit: hicap_value_results
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_broken_gene_percent_identity_arg = min_broken_gene_percent_identity ?: 0.80
    def broken_gene_length_arg = broken_gene_length ?: 60
    def min_gene_percent_coverage_arg = min_gene_percent_coverage ?: 0.80
    def min_gene_percent_identity_arg = min_gene_percent_identity ?: 0.70
    
    """
    mkdir output_dir
    
    # Run HiCAP
    hicap \\
        -q ${assembly} \\
        -o output_dir \\
        --gene_coverage ${min_gene_percent_coverage_arg} \\
        --gene_identity ${min_gene_percent_identity_arg} \\
        --broken_gene_length ${broken_gene_length_arg} \\
        --broken_gene_identity ${min_broken_gene_percent_identity_arg} \\
        --threads ${task.cpus} \\
        ${args}
    
    filename=\$(basename ${assembly})
    
    # If there are no hits for a cap locus, no file is produced
    if [ ! -f ./output_dir/\${filename%.*}.tsv ]; then
        echo "No_hits" > hicap_serotype_value.txt
        echo "No_hits" > hicap_genes_value.txt
        touch ${prefix}.hicap.tsv
    else
        tail -n1 ./output_dir/\${filename%.*}.tsv | cut -f 2 > hicap_serotype_value.txt
        tail -n1 ./output_dir/\${filename%.*}.tsv | cut -f 4 > hicap_genes_value.txt
        mv ./output_dir/\${filename%.*}.tsv ${prefix}.hicap.tsv
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicap: \$(hicap --version 2>&1 | sed 's/^hicap //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.hicap.tsv
    echo "a" > hicap_serotype_value.txt
    echo "bexA" > hicap_genes_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicap: \$(hicap --version 2>&1 | sed 's/^hicap //')
    END_VERSIONS
    """
}