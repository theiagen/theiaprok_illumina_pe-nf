process VIRULENCEFINDER {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/virulencefinder:2.0.4"

    input:
    tuple val(meta), path(assembly)
    val database
    val min_percent_coverage
    val min_percent_identity

    output:
    tuple val(meta), path("*_results_tab.tsv"), emit: virulence_report
    tuple val(meta), path("VIRULENCE_FACTORS.txt"), emit: virulence_factors
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database_arg = database ? database: "virulence_ecoli"
    def coverage_arg = min_percent_coverage ? "-l ${min_percent_coverage}" : ""
    def identity_arg = min_percent_identity ? "-t ${min_percent_identity}" : ""
    
    """
    date | tee DATE

    mkdir tmp
    
    virulencefinder.py \\
        -i ${assembly} \\
        -o . \\
        -tmp tmp \\
        -x \\
        -d ${database_arg} \\
        ${coverage_arg} \\
        ${identity_arg} \\
        ${args}
    
    # rename output files
    mv results_tab.tsv ${prefix}_results_tab.tsv

    # parse 2nd column (Virulence factor) of _tab.tsv file into a comma-separated string
    tail -n+2 ${prefix}_results_tab.tsv | awk '{print \$2}' | uniq | paste -s -d, - | tee VIRULENCE_FACTORS.txt

    # if virulencefinder fails/no hits are found, the results_tab.tsv file will still exist but only be the header
    # check to see if VIRULENCE_FACTORS is just whitespace
    # if so, say that no virulence factors were found instead
    if ! grep -q '[^[:space:]]' VIRULENCE_FACTORS.txt ; then 
      echo "No virulence factors found" | tee VIRULENCE_FACTORS.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        virulencefinder: \$(virulencefinder.py --version 2>&1 | grep -oP 'VirulenceFinder \\K[0-9.]+' || echo "2.0.4")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_results_tab.tsv
    echo "No virulence genes detected" > VIRULENCE_FACTORS.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        virulencefinder: 2.0.4
    END_VERSIONS
    """
}