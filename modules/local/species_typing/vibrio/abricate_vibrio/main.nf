process ABRICATE_VIBRIO {
    tag "$meta.id"
    label 'process_single'

    container "us-docker.pkg.dev/general-theiagen/staphb/abricate:1.0.1-vibrio-cholera"

    input:
    tuple val(meta), path(assembly)
    val database_type 
    val min_percent_identity
    val min_percent_coverage

    output:
    tuple val(meta), path("*_abricate_hits.tsv"), emit: abricate_hits
    tuple val(meta), path("CTXA.txt"), emit: ctxa
    tuple val(meta), path("OMPW.txt"), emit: ompw
    tuple val(meta), path("TOXR.txt"), emit: toxr
    tuple val(meta), path("BIOTYPE.txt"), emit: biotype
    tuple val(meta), path("SEROGROUP.txt"), emit: serogroup
    path("versions.yml"), emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database = database_type ?: "vibrio"
    def min_percent_cov = min_percent_coverage ? "--mincov ${min_percent_coverage}": ""
    def min_percent_ident = min_percent_identity ? "--minid ${min_percent_identity}": ""
    """
    date | tee DATE    
    # run abricate
    abricate \
      --db ${database} \
      ${min_percent_ident} \
      ${min_percent_cov} \
      --threads ${task.cpus} \
      --nopath \
      ${assembly} > ${prefix}_abricate_hits.tsv
    
    # presence or absence genes - ctxA, ompW and toxR
    # if empty report as (not detected)
    if grep -q '\\tctxA\\t' ${prefix}_abricate_hits.tsv; then echo "(not detected)" > CTXA.txt; else echo "present" > CTXA.txt; fi
    if grep -q '\\tompW\\t' ${prefix}_abricate_hits.tsv; then echo "(not detected)" > OMPW.txt; else echo "present" > OMPW.txt; fi
    if grep -q '\\ttoxR\\t' ${prefix}_abricate_hits.tsv; then echo "(not detected)" > TOXR.txt; else echo "present" > TOXR.txt; fi

    # biotype - tcpA classical or tcpA ElTor
    if grep -q '\ttcpA_classical\t' ${prefix}_abricate_hits.tsv; then
      echo "tcpA_classical" > BIOTYPE.txt
    elif grep -q '\ttcpA_ElTor\t' ${prefix}_abricate_hits.tsv; then
      echo "tcpA_ElTor" > BIOTYPE.txt
    else
      echo "(not detected)" > BIOTYPE.txt
    fi

    # serogroup - O1 or O139
    if grep -q '\twbeN_O1\t' ${prefix}_abricate_hits.tsv; then
      echo "O1" > SEROGROUP.txt
    elif grep -q '\twbfR_O139\t' ${prefix}_abricate_hits.tsv; then
      echo "O139" > SEROGROUP.txt
    else
      echo "(not detected)" > SEROGROUP.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$(abricate -v)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_abricate_hits.tsv
    touch CTXA.txt
    touch OMPW.txt
    touch TOXR.txt
    touch BIOTYPE.txt
    touch SEROGROUP.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$(abricate -v)
    END_VERSIONS
    """

}