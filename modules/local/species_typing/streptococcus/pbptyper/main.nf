process PBPTYPER {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/pbptyper:1.0.4"

    input:
    tuple val(meta), path(assembly)
    path database
    val min_percent_identity
    val min_percent_coverage

    output:
    tuple val(meta), path("pbptype.txt")          , emit: pbtyper_predicted_1a_2b_2x
    tuple val(meta), path("*.tsv")                , emit: pbtyper_predicted_tsv
    tuple val(meta), path("*-1A.tblastn.tsv")    , emit: pbtyper_pbptype_1a_tsv
    tuple val(meta), path("*-2B.tblastn.tsv")    , emit: pbtyper_pbptype_2b_tsv
    tuple val(meta), path("*-2X.tblastn.tsv")    , emit: pbtyper_pbptype_2x_tsv
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def db = database ? "--db ${database}" : ""
    def min_percent_identity_arg = min_percent_identity ?: 95
    def min_percent_coverage_arg = min_percent_coverage ?: 95
    
    """
    # Run pbptyper
    pbptyper \\
        --assembly ${assembly} \\
        ${db} \\
        --min_pident ${min_percent_identity_arg} \\
        --min_coverage ${min_percent_coverage_arg} \\
        --prefix ${prefix} \\
        --outdir ./ \\
        ${args}
    
    # Parse output TSV for PBP type
    cut -f 2 ${prefix}.tsv | tail -n 1 > pbptype.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbptyper: \$(pbptyper --version | sed 's/pbptyper, //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    touch ${prefix}-1A.tblastn.tsv
    touch ${prefix}-2B.tblastn.tsv
    touch ${prefix}-2X.tblastn.tsv
    echo "unknown" > pbptype.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbptyper: \$(pbptyper --version | sed 's/pbptyper, //')
    END_VERSIONS
    """
}