process KLEBORATE {
    tag "$meta.id"
    label "process_medium"

    container 'us-docker.pkg.dev/general-theiagen/staphb/kleborate:2.2.0'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*_kleborate_out.tsv")         , emit: kleborate_report
    tuple val(meta), path("SPECIES")                     , emit: kleborate_species
    tuple val(meta), path("MLST_SEQUENCE_TYPE")          , emit: kleborate_mlst_sequence_type
    tuple val(meta), path("VIRULENCE_SCORE")             , emit: kleborate_virulence_score
    tuple val(meta), path("RESISTANCE_SCORE")            , emit: kleborate_resistance_score
    tuple val(meta), path("NUM_RESISTANCE_GENES")        , emit: kleborate_num_resistance_genes
    tuple val(meta), path("BLA_RESISTANCE_GENES")        , emit: kleborate_bla_resistance_genes
    tuple val(meta), path("ESBL_RESISTANCE_GENES")       , emit: kleborate_esbl_resistance_genes
    tuple val(meta), path("KEY_RESISTANCE_GENES")        , emit: kleborate_key_resistance_genes
    tuple val(meta), path("GENOMIC_RESISTANCE_MUTATIONS"), emit: kleborate_genomic_resistance_mutations
    tuple val(meta), path("K_TYPE")                      , emit: kleborate_k_type
    tuple val(meta), path("K_LOCUS")                     , emit: kleborate_k_locus
    tuple val(meta), path("O_TYPE")                      , emit: kleborate_o_type
    tuple val(meta), path("O_LOCUS")                     , emit: kleborate_o_locus
    tuple val(meta), path("K_LOCUS_CONFIDENCE")          , emit: kleborate_k_locus_confidence
    tuple val(meta), path("O_LOCUS_CONFIDENCE")          , emit: kleborate_o_locus_confidence
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    def skip_resistance = params.kleborate_skip_resistance ? '' : '--resistance'
    def skip_kaptive = params.kleborate_skip_kaptive ? '' : '--kaptive'
    def min_identity = params.kleborate_min_percent_identity ?: 90.0
    def min_coverage = params.kleborate_min_percent_coverage ?: 80.0
    def min_spurious_identity = params.kleborate_min_spurious_percent_identity ?: 80.0
    def min_spurious_coverage = params.kleborate_min_spurious_percent_coverage ?: 40.0
    def min_kaptive_confidence = params.kleborate_min_kaptive_confidence ?: 'Good'
    
    """
    # Run Kleborate on the input assembly
    kleborate \\
        ${skip_resistance} \\
        ${skip_kaptive} \\
        --min_identity ${min_identity} \\
        --min_coverage ${min_coverage} \\
        --min_spurious_identity ${min_spurious_identity} \\
        --min_spurious_coverage ${min_spurious_coverage} \\
        --min_kaptive_confidence ${min_kaptive_confidence} \\
        --outfile ${prefix}_kleborate_out.tsv \\
        --assemblies ${assembly} \\
        --all \\
        ${args}
    
    # Call parser
    kleborate_parser.py \\
        ${prefix}_kleborate_out.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kleborate: \$(kleborate --version | sed 's/Kleborate v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_kleborate_out.tsv
    touch SPECIES
    touch MLST_SEQUENCE_TYPE
    touch VIRULENCE_SCORE
    touch RESISTANCE_SCORE
    touch NUM_RESISTANCE_GENES
    touch BLA_RESISTANCE_GENES
    touch ESBL_RESISTANCE_GENES
    touch KEY_RESISTANCE_GENES
    touch GENOMIC_RESISTANCE_MUTATIONS
    touch K_TYPE
    touch K_LOCUS
    touch O_TYPE
    touch O_LOCUS
    touch K_LOCUS_CONFIDENCE
    touch O_LOCUS_CONFIDENCE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kleborate: \$(kleborate --version | sed 's/Kleborate v//' || echo "2.2.0")
    END_VERSIONS
    """
}