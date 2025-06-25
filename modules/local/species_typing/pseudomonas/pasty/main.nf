process PASTY {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/pasty:1.0.3"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.tsv")           , emit: pasty_summary_tsv
    tuple val(meta), path("*.blastn.tsv")    , emit: pasty_blast_hits
    tuple val(meta), path("*.details.tsv")   , emit: pasty_all_serogroups
    tuple val(meta), path("SEROGROUP")       , emit: pasty_serogroup
    tuple val(meta), path("COVERAGE")        , emit: pasty_serogroup_coverage
    tuple val(meta), path("FRAGMENTS")       , emit: pasty_serogroup_fragments
    tuple val(meta), path("COMMENT")         , emit: pasty_comment
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_percent_identity = params.pasty_min_percent_identity ?: 95
    def min_percent_coverage = params.pasty_min_percent_coverage ?: 95
    
    """
    # Run pasty on input assembly
    pasty \\
        --assembly ${assembly} \\
        --min_pident ${min_percent_identity} \\
        --min_coverage ${min_percent_coverage} \\
        --prefix ${prefix} \\
        --outdir . \\
        ${args}
    
    # Parse outputs using external script
    awk 'FNR==2' "${prefix}.tsv" | cut -d\$'\\t' -f2 > SEROGROUP
    awk 'FNR==2' "${prefix}.tsv" | cut -d\$'\\t' -f3 > COVERAGE
    awk 'FNR==2' "${prefix}.tsv" | cut -d\$'\\t' -f4 > FRAGMENTS
    awk 'FNR==2' "${prefix}.tsv" | cut -d\$'\\t' -f5 > COMMENT

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pasty: \$(pasty --version | sed 's/pasty, version //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    touch ${prefix}.blastn.tsv
    touch ${prefix}.details.tsv
    touch SEROGROUP
    touch COVERAGE
    touch FRAGMENTS
    touch COMMENT

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pasty: \$(pasty --version | sed 's/pasty, version //')
    END_VERSIONS
    """
}