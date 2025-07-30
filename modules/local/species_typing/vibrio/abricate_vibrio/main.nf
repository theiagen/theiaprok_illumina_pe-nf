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
    tuple val(meta), path("*_value.txt"), emit: abricate_value_results
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
    if grep -q '\\tctxA\\t' ${prefix}_abricate_hits.tsv; then echo "(not detected)" > CTXA.txt; else echo "present" > abricate_vibrio_CTXA_value.txt; fi
    if grep -q '\\tompW\\t' ${prefix}_abricate_hits.tsv; then echo "(not detected)" > OMPW.txt; else echo "present" > abricate_vibrio_OMPW_value.txt; fi
    if grep -q '\\ttoxR\\t' ${prefix}_abricate_hits.tsv; then echo "(not detected)" > TOXR.txt; else echo "present" > abricate_vibrio_TOXR_value.txt; fi

    # biotype - tcpA classical or tcpA ElTor
    if grep -q '\ttcpA_classical\t' ${prefix}_abricate_hits.tsv; then
      echo "tcpA_classical" > abricate_vibrio_BIOTYPE_value.txt
    elif grep -q '\ttcpA_ElTor\t' ${prefix}_abricate_hits.tsv; then
      echo "tcpA_ElTor" > abricate_vibrio_BIOTYPE_value.txt
    else
      echo "(not detected)" > abricate_vibrio_BIOTYPE_value.txt
    fi

    # serogroup - O1 or O139
    if grep -q '\twbeN_O1\t' ${prefix}_abricate_hits.tsv; then
      echo "O1" > abricate_vibrio_SEROGROUP_value.txt
    elif grep -q '\twbfR_O139\t' ${prefix}_abricate_hits.tsv; then
      echo "O139" > abricate_vibrio_SEROGROUP_value.txt
    else
      echo "(not detected)" > abricate_vibrio_SEROGROUP_value.txt
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
    touch abricate_vibrio_CTXA.txt
    touch abricate_vibrio_OMPW.txt
    touch abricate_vibrio_TOXR.txt
    touch abricate_vibrio_BIOTYPE.txt
    touch abricate_vibrio_SEROGROUP.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$(abricate -v)
    END_VERSIONS
    """

}