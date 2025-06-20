process SPADES {
    tag "$meta.id"
    label "process_medium"
    
    container "us-docker.pkg.dev/general-theiagen/staphb/spades:4.1.0"

    input:
    tuple val(meta), path(reads)
    val kmers
    val spades_type

    output:
    tuple val(meta), path('*.contigs.fa'), emit: contigs
    tuple val(meta), path('*.contigs.gfa'), emit: gfa, optional: true
    tuple val(meta), path("*.log")        , emit: log
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def maxmem = task.memory.toGiga()
    def type = spades_type ?: 'isolate'
    def k_mer = kmers ? "-k ${kmers}" : ""
    def reads_input = meta.single_end ? "-s ${reads}" : "-1 ${reads[0]} -2 ${reads[1]}"
    
    """
    spades.py \\
        --${type} \\
        ${reads_input} \\
        ${k_mer} \\
        --threads ${task.cpus} \\
        --memory ${maxmem} \\
        --phred-offset 33 \\
        -o spades \\
        ${args}

    # Handle metaviral special case
    if [[ "${type}" == "metaviral" ]]; then
        if [[ -f spades/contigs.fasta ]]; then
            echo "PASS" > spades_status.txt
            mv spades/contigs.fasta ${prefix}_${type}spades_contigs.fa
            if [[ -f spades/assembly_graph_with_scaffolds.gfa ]]; then
                mv spades/assembly_graph_with_scaffolds.gfa ${prefix}_${type}spades_contigs.gfa
            fi
        else
            echo "FAIL" > spades_status.txt
            touch ${prefix}_${type}spades_contigs.fa
        fi
    else
        echo "PASS" > spades_status.txt
        mv spades/contigs.fasta ${prefix}_${type}spades_contigs.fa
        if [[ -f spades/assembly_graph_with_scaffolds.gfa ]]; then
            mv spades/assembly_graph_with_scaffolds.gfa ${prefix}_${type}spades_contigs.gfa
        fi
    fi

    mv spades/spades.log ${prefix}_spades.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spades: \$(spades.py --version 2>&1 | sed 's/^.*SPAdes genome assembler v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def type = spades_type ?: 'isolate'
    """
    touch ${prefix}_${type}spades_contigs.fa
    touch ${prefix}_${type}spades_contigs.gfa
    touch ${prefix}_spades.log
    echo "PASS" > spades_status.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spades: \$(spades.py --version 2>&1 | sed 's/^.*SPAdes genome assembler v//; s/ .*\$//')
    END_VERSIONS
    """
}