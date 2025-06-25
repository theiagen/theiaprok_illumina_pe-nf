process NGMASTER {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/ngmaster:1.0.0"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.ngmaster.tsv")      , emit: ngmast_report
    tuple val(meta), path("NGMAST_SEQUENCE_TYPE"), emit: ngmast_sequence_type
    tuple val(meta), path("NGMAST_PORB")         , emit: ngmast_porb_allele
    tuple val(meta), path("NGMAST_TBPB")         , emit: ngmast_tbpb_allele
    tuple val(meta), path("NGSTAR_SEQUENCE_TYPE"), emit: ngstar_sequence_type
    tuple val(meta), path("NGSTAR_PENA")         , emit: ngstar_pena_allele
    tuple val(meta), path("NGSTAR_MTRR")         , emit: ngstar_mtrr_allele
    tuple val(meta), path("NGSTAR_PORB")         , emit: ngstar_porb_allele
    tuple val(meta), path("NGSTAR_PONA")         , emit: ngstar_pona_allele
    tuple val(meta), path("NGSTAR_GYRA")         , emit: ngstar_gyra_allele
    tuple val(meta), path("NGSTAR_PARC")         , emit: ngstar_parc_allele
    tuple val(meta), path("NGSTAR_23S")          , emit: ngstar_23s_allele
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # Run ngmaster on input assembly
    # Note: ngmaster 1.0.0 fails when either mincov or minid flags are supplied
    # so we're forced to stick with default minid of 90 and mincov of 10
    # See: https://github.com/MDU-PHL/ngmaster/issues/39
    ngmaster \\
        ${assembly} \\
        ${args} \\
        > ${prefix}.ngmaster.tsv
    
    # parse output TSV
    # first one is tricky since MLSTs are in the 3rd column, separated by a /
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$3}' | cut -d '/' -f 1 | tee NGMAST_SEQUENCE_TYPE
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$3}' | cut -d '/' -f 2 | tee NGSTAR_SEQUENCE_TYPE
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$4}' | tee NGMAST_PORB
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$5}' | tee NGMAST_TBPB
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$6}' | tee NGSTAR_PENA
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$7}' | tee NGSTAR_MTRR
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$8}' | tee NGSTAR_PORB
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$9}' | tee NGSTAR_PONA
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$10}' | tee NGSTAR_GYRA
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$11}' | tee NGSTAR_PARC
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$12}' | tee NGSTAR_23S

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ngmaster: \$(ngmaster --version 2>&1 | sed 's/^.*ngmaster //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.ngmaster.tsv
    touch NGMAST_SEQUENCE_TYPE
    touch NGMAST_PORB
    touch NGMAST_TBPB
    touch NGSTAR_SEQUENCE_TYPE
    touch NGSTAR_PENA
    touch NGSTAR_MTRR
    touch NGSTAR_PORB
    touch NGSTAR_PONA
    touch NGSTAR_GYRA
    touch NGSTAR_PARC
    touch NGSTAR_23S

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ngmaster: \$(ngmaster --version 2>&1 | sed 's/^.*ngmaster //' || echo "1.0.0")
    END_VERSIONS
    """
}