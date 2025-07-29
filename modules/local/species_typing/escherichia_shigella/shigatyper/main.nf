process SHIGATYPER {
    tag "$meta.id"
    label "process_medium"

    container "us-docker.pkg.dev/general-theiagen/staphb/shigatyper:2.0.5"

    input:
    tuple val(meta), path(reads)
    val read1_is_ont

    output:
    tuple val(meta), path("*_shigatyper_summary.tsv"), emit: shigatyper_summary
    tuple val(meta), path("*_shigatyper_hits.tsv"), emit: shigatyper_hits
    tuple val(meta), path("*_value.txt"), emit: shigatyper_value_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def is_ont = read1_is_ont ?: false
    
    def input_reads = ""
    if (!reads[1]) {
        // Single-end or ONT
        if (is_ont) {
            input_reads = "--SE ${reads[0]} --ont"
        } else {
            input_reads = "--SE ${reads[0]}"
        }
    } else {
        // Paired-end
        input_reads = "--R1 ${reads[0]} --R2 ${reads[1]}"
    }
    
    """
    set -euo pipefail
    
    echo "INPUT_READS set to: ${input_reads}"
    
    # run shigatyper. 2 output files will be ${prefix}.tsv and ${prefix}-hits.tsv
    echo "Running ShigaTyper..."
    shigatyper \\
        ${input_reads} \\
        -n ${prefix} \\
        ${args}
    
    # rename output TSVs to be more descriptive
    mv -v ${prefix}.tsv ${prefix}_shigatyper_summary.tsv
    
    # if 0 reads map to the reference sequences, shigatyper will not produce a hits file
    # so check for the existence of the hits file before renaming
    if [ -f ${prefix}-hits.tsv ]; then
        echo "Shigatyper hits file exists, renaming..."
        mv -v ${prefix}-hits.tsv ${prefix}_shigatyper_hits.tsv
    else
        echo "Hits file does not exist, creating empty hits file..."
        touch ${prefix}_shigatyper_hits.tsv
    fi
    
    # parse summary tsv for prediction, ipaB absence/presence, and notes
    prediction=\$(cut -f 2 ${prefix}_shigatyper_summary.tsv | tail -n 1)
    ipaB_status=\$(cut -f 3 ${prefix}_shigatyper_summary.tsv | tail -n 1)
    notes=\$(cut -f 4 ${prefix}_shigatyper_summary.tsv | tail -n 1)
    
    # if shigatyper notes field is EMPTY, write string saying it is empty
    if [ -z "\$notes" ]; then
       notes="ShigaTyper notes field was empty"
    fi
    
    echo "\$prediction" > SHIGATYPER_PREDICTION_value.txt
    echo "\$ipaB_status" > SHIGATYPER_IPAB_value.txt
    echo "\$notes" > SHIGATYPER_NOTES_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shigatyper: \$(shigatyper --version | sed 's/ShigaTyper //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_shigatyper_summary.tsv
    touch ${prefix}_shigatyper_hits.tsv
    echo "No serotype predicted" > SHIGATYPER_PREDICTION_value.txt
    echo "Not determined" > SHIGATYPER_IPAB_value.txt
    echo "ShigaTyper notes field was empty" > SHIGATYPER_NOTES_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shigatyper: \$(shigatyper --version | sed 's/ShigaTyper //')
    END_VERSIONS
    """
}