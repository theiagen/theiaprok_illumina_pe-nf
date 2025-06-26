process KAPTIVE {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/kaptive:2.0.3"

    input:
    tuple val(meta), path(assembly)
    val start_end_margin
    val min_percent_coverage
    val min_percent_identity
    val low_gene_percent_identity

    output:
    tuple val(meta), path("*_kaptive_out_k_table.tsv"), emit: k_table
    tuple val(meta), path("*_kaptive_out_oc_table.tsv"), emit: oc_table
    tuple val(meta), path("BEST_MATCH_LOCUS_K"), emit: k_match
    tuple val(meta), path("BEST_MATCH_TYPE_K"), emit: k_type
    tuple val(meta), path("MATCH_CONFIDENCE_K"), emit: k_confidence
    tuple val(meta), path("NUM_EXPECTED_INSIDE_K"), emit: k_expected_inside_count
    tuple val(meta), path("EXPECTED_GENES_IN_LOCUS_K"), emit: k_expected_inside_genes
    tuple val(meta), path("NUM_EXPECTED_OUTSIDE_K"), emit: k_expected_outside_count
    tuple val(meta), path("EXPECTED_GENES_OUT_LOCUS_K"), emit: k_expected_outside_genes
    tuple val(meta), path("NUM_OTHER_INSIDE_K"), emit: k_other_inside_count
    tuple val(meta), path("OTHER_GENES_IN_LOCUS_K"), emit: k_other_inside_genes
    tuple val(meta), path("NUM_OTHER_OUTSIDE_K"), emit: k_other_outside_count
    tuple val(meta), path("OTHER_GENES_OUT_LOCUS_K"), emit: k_other_outside_genes
    tuple val(meta), path("BEST_MATCH_LOCUS_OC"), emit: oc_match
    tuple val(meta), path("BEST_MATCH_TYPE_OC"), emit: oc_type
    tuple val(meta), path("MATCH_CONFIDENCE_OC"), emit: oc_confidence
    tuple val(meta), path("NUM_EXPECTED_INSIDE_OC"), emit: oc_expected_inside_count
    tuple val(meta), path("EXPECTED_GENES_IN_LOCUS_OC"), emit: oc_expected_inside_genes
    tuple val(meta), path("NUM_EXPECTED_OUTSIDE_OC"), emit: oc_expected_outside_count
    tuple val(meta), path("EXPECTED_GENES_OUT_LOCUS_OC"), emit: oc_expected_outside_genes
    tuple val(meta), path("NUM_OTHER_INSIDE_OC"), emit: oc_other_inside_count
    tuple val(meta), path("OTHER_GENES_IN_LOCUS_OC"), emit: oc_other_inside_genes
    tuple val(meta), path("NUM_OTHER_OUTSIDE_OC"), emit: oc_other_outside_count
    tuple val(meta), path("OTHER_GENES_OUT_LOCUS_OC"), emit: oc_other_outside_genes
    path "versions.yml", emit: versions

    when:
    task.ext.prefix || task.ext.stub || task.ext.skip

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def start_end_margin_arg = start_end_margin ? start_end_margin : 10
    def min_percent_coverage_arg = min_percent_coverage ? min_percent_coverage : 90.0
    def min_percent_identity_arg = min_percent_identity ? min_percent_identity : 80.0
    def low_gene_percent_identity_arg = low_gene_percent_identity ? low_gene_percent_identity : 95.0
    """
    KAPTIVE_DIR=\$(dirname "\$(which kaptive.py)")

    # Run for k locus
    kaptive.py \
    -t ${task.cpus} \
    --start_end_margin ${start_end_margin_arg} \
    --min_gene_id ${min_percent_identity_arg} \
    --min_gene_cov ${min_percent_coverage_arg} \
    --low_gene_id  ${low_gene_percent_identity_arg} \
    --no_seq_out \
    --no_json \
    --out ${prefix}_kaptive_out_k \
    --assembly ${assembly} \
    --k_refs \${KAPTIVE_DIR}/reference_database/Acinetobacter_baumannii_k_locus_primary_reference.gbk

    # Extract kaptive output tables
    kaptive_parser.py \
    --mode k \
    --input ${prefix}_kaptive_out_k_table.txt

    # Run for oc locus
    kaptive.py \
    -t ${task.cpus} \
    --start_end_margin ${start_end_margin_arg} \
    --min_gene_id ${min_percent_identity_arg} \
    --min_gene_cov ${min_percent_coverage_arg} \
    --low_gene_id  ${low_gene_percent_identity_arg} \
    --no_seq_out \
    --no_json \
    --out ${prefix}_kaptive_out_oc \
    --assembly ${assembly} \
    --k_refs \${KAPTIVE_DIR}/reference_database/Acinetobacter_baumannii_OC_locus_primary_reference.gbk

    # Extract kaptive output tables for oc locus
    kaptive_parser.py \
    --mode oc \
    --input ${prefix}_kaptive_out_oc_table.txt

    mv -v ${prefix}_kaptive_out_k_table.txt ${prefix}_kaptive_out_k_table.tsv
    mv -v ${prefix}_kaptive_out_oc_table.txt ${prefix}_kaptive_out_oc_table.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kaptive: \$(kaptive.py --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_kaptive_out_k_table.tsv
    touch ${prefix}_kaptive_out_oc_table.tsv
    touch BEST_MATCH_LOCUS_K
    touch BEST_MATCH_TYPE_K
    touch MATCH_CONFIDENCE_K
    touch NUM_EXPECTED_INSIDE_K
    touch EXPECTED_GENES_IN_LOCUS_K
    touch NUM_EXPECTED_OUTSIDE_K
    touch EXPECTED_GENES_OUT_LOCUS_K
    touch NUM_OTHER_INSIDE_K
    touch OTHER_GENES_IN_LOCUS_K
    touch NUM_OTHER_OUTSIDE_K
    touch OTHER_GENES_OUT_LOCUS_K
    touch BEST_MATCH_LOCUS_OC
    touch BEST_MATCH_TYPE_OC
    touch MATCH_CONFIDENCE_OC
    touch NUM_EXPECTED_INSIDE_OC
    touch EXPECTED_GENES_IN_LOCUS_OC
    touch NUM_EXPECTED_OUTSIDE_OC
    touch EXPECTED_GENES_OUT_LOCUS_OC
    touch NUM_OTHER_INSIDE_OC
    touch OTHER_GENES_IN_LOCUS_OC
    touch NUM_OTHER_OUTSIDE_OC
    touch OTHER_GENES_OUT_LOCUS_OC

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kaptive: \$(kaptive.py --version)
    END_VERSIONS
    """
}