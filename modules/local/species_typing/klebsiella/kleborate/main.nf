process KLEBORATE {
    tag "$meta.id"
    label "process_medium"

    container 'us-docker.pkg.dev/general-theiagen/staphb/kleborate:2.2.0'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*_kleborate_out.tsv")         , emit: kleborate_report
    tuple val(meta), path("*_value_results.txt")         , emit: kleborate_value_results
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

    # Rename output files
    mv SPECIES kleborate_SPECIES_value.txt
    mv MLST_SEQUENCE_TYPE kleborate_MLST_SEQUENCE_TYPE_value.txt
    mv VIRULENCE_SCORE kleborate_VIRULENCE_SCORE_value.txt
    mv RESISTANCE_SCORE kleborate_RESISTANCE_SCORE_value.txt
    mv NUM_RESISTANCE_GENES kleborate_NUM_RESISTANCE_GENES_value.txt
    mv BLA_RESISTANCE_GENES kleborate_BLA_RESISTANCE_GENES
    mv ESBL_RESISTANCE_GENES kleborate_ESBL_RESISTANCE_GENES
    mv KEY_RESISTANCE_GENES kleborate_KEY_RESISTANCE_GENES
    mv GENOMIC_RESISTANCE_MUTATIONS kleborate_GENOMIC_RESISTANCE_MUTATIONS
    mv K_TYPE kleborate_K_TYPE_value.txt
    mv K_LOCUS kleborate_K_LOCUS_value.txt
    mv O_TYPE kleborate_O_TYPE_value.txt
    mv O_LOCUS kleborate_O_LOCUS_value.txt
    mv K_LOCUS_CONFIDENCE kleborate_K_LOCUS_CONFIDENCE_value.txt
    mv O_LOCUS_CONFIDENCE kleborate_O_LOCUS_CONFIDENCE_value.txt

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