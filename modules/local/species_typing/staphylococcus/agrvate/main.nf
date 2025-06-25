process AGRVATE {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/biocontainers/agrvate:1.0.2--hdfd78af_0"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.agrvate.tsv")    , emit: agrvate_summary
    tuple val(meta), path("*.agrvate.tar.gz") , emit: agrvate_results
    tuple val(meta), path("AGR_GROUP")        , emit: agrvate_agr_group
    tuple val(meta), path("AGR_MATCH_SCORE")  , emit: agrvate_agr_match_score
    tuple val(meta), path("AGR_CANONICAL")    , emit: agrvate_agr_canonical
    tuple val(meta), path("AGR_MULTIPLE")     , emit: agrvate_agr_multiple
    tuple val(meta), path("AGR_NUM_FRAMESHIFTS"), emit: agrvate_agr_num_frameshifts
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def typing_only = params.agrvate_typing_only ? '--typing-only' : ''
    
    """
    # Run agrvate on assembly
    # Using -m flag for mummer frameshift detection since usearch is not available
    agrvate \\
        ${typing_only} \\
        -i ${assembly} \\
        -m \\
        ${args}
    
    # agrvate names output directory and file based on name of .fasta file
    # so <prefix>.fasta as input results in <prefix>-results/ outdir
    # and results in <prefix>-results/<prefix>-summary.tab files
    basename=\$(basename ${assembly})
    # Strip off anything after the period
    fasta_prefix=\${basename%.*}
    
    # Rename outputs summary TSV to include samplename
    mv -v "\${fasta_prefix}-results/\${fasta_prefix}-summary.tab" ${prefix}.agrvate.tsv
    
    # These outputs are not edited further
    cut -f 2 ${prefix}.agrvate.tsv | tail -n 1 | tee AGR_GROUP
    cut -f 3 ${prefix}.agrvate.tsv | tail -n 1 | tee AGR_MATCH_SCORE
    # Parse output summary TSV -- make temporary files for noclobber rule in nf
    cut -f 4 ${prefix}.agrvate.tsv | tail -n 1 | tee AGR_CANONICAL.tmp
    cut -f 5 ${prefix}.agrvate.tsv | tail -n 1 | tee AGR_MULTIPLE.tmp
    cut -f 6 ${prefix}.agrvate.tsv | tail -n 1 | tee AGR_NUM_FRAMESHIFTS.tmp
    
    # Edit output string AGR_CANONICAL to be more informative
    # https://github.com/VishnuRaghuram94/AgrVATE#results
    if [[ \$(cat AGR_CANONICAL.tmp) == 1 ]]; then
        echo "1. canonical agrD" > AGR_CANONICAL
    elif [[ \$(cat AGR_CANONICAL.tmp) == 0 ]]; then
        echo "0. non-canonical agrD" > AGR_CANONICAL
    elif [[ \$(cat AGR_CANONICAL.tmp) == "u" ]]; then
        echo "u. unknown agrD" > AGR_CANONICAL
    else 
        echo "result unrecognized, please see summary agrvate TSV file" > AGR_CANONICAL
    fi
    
    # Edit output string AGR_MULTIPLE to be more informative
    # https://github.com/VishnuRaghuram94/AgrVATE#results
    if [[ \$(cat AGR_MULTIPLE.tmp) == "s" ]]; then
        echo "s. single agr group found" > AGR_MULTIPLE
    elif [[ \$(cat AGR_MULTIPLE.tmp) == "m" ]]; then
        echo "m. multiple agr groups found" > AGR_MULTIPLE
    elif [[ \$(cat AGR_MULTIPLE.tmp) == "u" ]]; then
        echo "u. unknown agr groups found" > AGR_MULTIPLE
    else 
        echo "result unrecognized, please see summary agrvate TSV file" > AGR_MULTIPLE
    fi
    
    # If AGR_NUM_FRAMESHIFTS is unknown, edit output string to be more informative
    # https://github.com/VishnuRaghuram94/AgrVATE#results
    if [[ \$(cat AGR_NUM_FRAMESHIFTS.tmp) == "u" ]]; then
        echo "u or unknown; agr operon not extracted" > AGR_NUM_FRAMESHIFTS
    else
        cp AGR_NUM_FRAMESHIFTS.tmp AGR_NUM_FRAMESHIFTS
    fi
    
    # Create tarball of all output files
    tar -czvf ${prefix}.agrvate.tar.gz "\${fasta_prefix}-results/"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agrvate: \$(agrvate -v 2>&1 | sed 's/agrvate v//;')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.agrvate.tsv
    touch ${prefix}.agrvate.tar
    gzip ${prefix}.agrvate.tar
    echo "unknown" > AGR_GROUP
    echo "unknown" > AGR_MATCH_SCORE
    echo "result unrecognized, please see summary agrvate TSV file" > AGR_CANONICAL
    echo "result unrecognized, please see summary agrvate TSV file" > AGR_MULTIPLE
    echo "u or unknown; agr operon not extracted" > AGR_NUM_FRAMESHIFTS

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agrvate: \$(agrvate -v 2>&1 | sed 's/agrvate v//;')
    END_VERSIONS
    """
}