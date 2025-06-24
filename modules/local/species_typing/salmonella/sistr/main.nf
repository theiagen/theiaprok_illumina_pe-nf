process SISTR {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "us-docker.pkg.dev/general-theiagen/staphb/sistr:1.1.3"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.tsv")             , emit: sistr_result
    tuple val(meta), path("*-allele.json")     , emit: sistr_allele_json
    tuple val(meta), path("*-allele.fasta")    , emit: sistr_allele_fasta
    tuple val(meta), path("*-cgmlst.csv")      , emit: sistr_cgmlst
    tuple val(meta), path("*_predicted_serotype.txt")     , emit: sistr_predicted_serotype
    tuple val(meta), path("*_serogroup.txt")              , emit: sistr_serogroup
    tuple val(meta), path("*_h1_antigens.txt")            , emit: sistr_h1_antigens
    tuple val(meta), path("*_h2_antigens.txt")            , emit: sistr_h2_antigens
    tuple val(meta), path("*_o_antigens.txt")             , emit: sistr_o_antigens
    tuple val(meta), path("*_serotype_cgmlst.txt")        , emit: sistr_serotype_cgmlst
    tuple val(meta), path("*_antigenic_formula.txt")      , emit: sistr_antigenic_formula
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def use_full_cgmlst_db = params.sistr_use_full_cgmlst_db ? '--use-full-cgmlst-db' : ''
    
    """
    sistr \\
        --qc \\
        ${use_full_cgmlst_db} \\
        --threads ${task.cpus} \\
        --alleles-output ${prefix}-allele.json \\
        --novel-alleles ${prefix}-allele.fasta \\
        --cgmlst-profiles ${prefix}-cgmlst.csv \\
        --output-prediction ${prefix} \\
        --output-format tab \\
        ${args} \\
        ${assembly}
    
    # Rename to .tsv suffix
    mv ${prefix}.tab ${prefix}.tsv

    # Parse sistr TSV
    cut -f 16 ${prefix}.tsv | tail -n 1 > ${prefix}_predicted_serotype.txt
    cut -f 15 ${prefix}.tsv | tail -n 1 > ${prefix}_serogroup.txt
    cut -f 10 ${prefix}.tsv | tail -n 1 > ${prefix}_h1_antigens.txt
    cut -f 11 ${prefix}.tsv | tail -n 1 > ${prefix}_h2_antigens.txt
    cut -f 12 ${prefix}.tsv | tail -n 1 > ${prefix}_o_antigens.txt
    cut -f 18 ${prefix}.tsv | tail -n 1 > ${prefix}_serotype_cgmlst.txt
    cut -f 1 ${prefix}.tsv | tail -n 1 > ${prefix}_antigenic_formula.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sistr: \$(sistr --version 2>&1 | sed 's/^.*sistr_cmd //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    touch ${prefix}-allele.json
    touch ${prefix}-allele.fasta
    touch ${prefix}-cgmlst.csv

    touch ${prefix}_predicted_serotype.txt
    touch ${prefix}_serogroup.txt
    touch ${prefix}_h1_antigens.txt
    touch ${prefix}_h2_antigens.txt
    touch ${prefix}_o_antigens.txt
    touch ${prefix}_serotype_cgmlst.txt
    touch ${prefix}_antigenic_formula.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sistr: \$(sistr --version 2>&1 | sed 's/^.*sistr_cmd //; s/ .*\$//')
    END_VERSIONS
    """
}