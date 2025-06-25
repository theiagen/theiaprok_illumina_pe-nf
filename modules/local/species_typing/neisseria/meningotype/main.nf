process MENINGOTYPE {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/meningotype:0.8.5--pyhdfd78af_0"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.tsv")               , emit: meningotype_report
    tuple val(meta), path("MENINGOTYPE_SEROTYPE"), emit: meningotype_serogroup
    tuple val(meta), path("MENINGOTYPE_PORA")    , emit: meningotype_pora
    tuple val(meta), path("MENINGOTYPE_FETA")    , emit: meningotype_feta
    tuple val(meta), path("MENINGOTYPE_PORB")    , emit: meningotype_porb
    tuple val(meta), path("MENINGOTYPE_FHBP")    , emit: meningotype_fhbp
    tuple val(meta), path("MENINGOTYPE_NHBA")    , emit: meningotype_nhba
    tuple val(meta), path("MENINGOTYPE_NADA")    , emit: meningotype_nada
    tuple val(meta), path("MENINGOTYPE_BAST")    , emit: meningotype_bast
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def finetype = params.meningotype_finetype ? '--finetype' : ''
    def porB = params.meningotype_porB ? '--porB' : ''
    def bast = params.meningotype_bast ? '--bast' : ''
    def mlst = params.meningotype_mlst ? '--mlst' : ''
    def all_typing = params.meningotype_all ? '--all' : ''
    // Default behavior matches WDL (finetype, porB, bast enabled)
    def default_finetype = finetype ?: '--finetype'
    def default_porB = porB ?: '--porB'
    def default_bast = bast ?: '--bast'
    
    """
    # Run meningotype on input assembly
    # Parameters:
    # --finetype      perform porA and fetA fine typing (default=off)
    # --porB          perform porB sequence typing (NEIS2020) (default=off)
    # --bast          perform Bexsero antigen sequence typing (BAST) (default=off)
    # --mlst          perform MLST (default=off)
    # --all           perform MLST, porA, fetA, porB, BAST typing (default=off)
    meningotype \\
        ${all_typing} \\
        ${default_finetype} \\
        ${default_porB} \\
        ${default_bast} \\
        ${mlst} \\
        --cpus ${task.cpus} \\
        ${assembly} \\
        ${args} \\
        > ${prefix}.tsv


    tail -1 ${prefix}.tsv | awk '{print \$2}' | tee MENINGOTYPE_SEROTYPE
    tail -1 ${prefix}.tsv | awk '{print \$5}' | tee MENINGOTYPE_PORA
    tail -1 ${prefix}.tsv | awk '{print \$6}' | tee MENINGOTYPE_FETA
    tail -1 ${prefix}.tsv | awk '{print \$7}' | tee MENINGOTYPE_PORB
    tail -1 ${prefix}.tsv | awk '{print \$8}' | tee MENINGOTYPE_FHBP
    tail -1 ${prefix}.tsv | awk '{print \$9}' | tee MENINGOTYPE_NHBA
    tail -1 ${prefix}.tsv | awk '{print \$10}' | tee MENINGOTYPE_NADA
    tail -1 ${prefix}.tsv | awk '{print \$11}' | tee MENINGOTYPE_BAST
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        meningotype: \$(meningotype --version 2>&1 | sed 's/^.*meningotype v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    touch MENINGOTYPE_SEROTYPE
    touch MENINGOTYPE_PORA
    touch MENINGOTYPE_FETA
    touch MENINGOTYPE_PORB
    touch MENINGOTYPE_FHBP
    touch MENINGOTYPE_NHBA
    touch MENINGOTYPE_NADA
    touch MENINGOTYPE_BAST

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        meningotype: \$(meningotype --version 2>&1 | sed 's/^.*meningotype v//' || echo "0.8.5")
    END_VERSIONS
    """
}