process MEGAHIT {
    tag "$meta.id"
    label "process_low"
    
    // This docker container works with nextflow, ours doesn't for some reason, but works in the WDL implementaion
    // Not sure what's going on, but this is a workaround for now
    container "community.wave.seqera.io/library/megahit_pigz:87a590163e594224"

    input:
    tuple val(meta), path(reads)
    val kmers

    output:
    tuple val(meta), path('*_megahit_contigs.fa'), emit: assembly_fasta
    tuple val(meta), path("*.log")        , emit: megahit_log
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_contig_len = params.min_contig_length ?: 1
    def memory_fraction = 0.9
    def k_list = kmers ? "--k-list ${kmers}" : ""
    def reads_input = meta.single_end ? "-r ${reads}" : "-1 ${reads[0]} -2 ${reads[1]}"
    
    """
    megahit \\
        ${reads_input} \\
        --min-contig-len ${min_contig_len} \\
        -m ${memory_fraction} \\
        -t ${task.cpus} \\
        -o megahit \\
        ${k_list} \\
        ${args}

    mv megahit/final.contigs.fa ${prefix}_megahit_contigs.fa
    mv megahit/log ${prefix}_megahit.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        megahit: \$(megahit --version 2>&1 | sed 's/^.*MEGAHIT v//' | sed 's/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_megahit_contigs.fa
    touch ${prefix}_megahit.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        megahit: \$(megahit --version 2>&1 | sed 's/^.*MEGAHIT v//' | sed 's/ .*\$//')
    END_VERSIONS
    """
}