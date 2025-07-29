process NGMASTER {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/ngmaster:1.0.0"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.ngmaster.tsv")      , emit: ngmast_report
    tuple val(meta), path("*_value.txt")         , emit: ngmast_value_results
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
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$3}' | cut -d '/' -f 1 | tee NGMAST_SEQUENCE_TYPE_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$3}' | cut -d '/' -f 2 | tee NGSTAR_SEQUENCE_TYPE_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$4}' | tee NGMAST_PORB_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$5}' | tee NGMAST_TBPB_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$6}' | tee NGSTAR_PENA_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$7}' | tee NGSTAR_MTRR_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$8}' | tee NGSTAR_PORB_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$9}' | tee NGSTAR_PONA_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$10}' | tee NGSTAR_GYRA_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$11}' | tee NGSTAR_PARC_value.txt
    tail -n 1 ${prefix}.ngmaster.tsv | awk '{print \$12}' | tee NGSTAR_23S_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ngmaster: \$(ngmaster --version 2>&1 | sed 's/^.*ngmaster //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.ngmaster.tsv
    touch NGMAST_SEQUENCE_TYPE_value.txt
    touch NGMAST_PORB_value.txt
    touch NGMAST_TBPB_value.txt
    touch NGSTAR_SEQUENCE_TYPE_value.txt
    touch NGSTAR_PENA_value.txt
    touch NGSTAR_MTRR_value.txt
    touch NGSTAR_PORB_value.txt
    touch NGSTAR_PONA_value.txt
    touch NGSTAR_GYRA_value.txt
    touch NGSTAR_PARC_value.txt
    touch NGSTAR_23S_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ngmaster: \$(ngmaster --version 2>&1 | sed 's/^.*ngmaster //' || echo "1.0.0")
    END_VERSIONS
    """
}