process VIBECHECK_VIBRIO {
    tag "$meta.id"
    label 'process_single'

    // conda "${moduleDir}/environment.yml"
    // container "docker.io/watronfire/vibecheck:2025.02.24"
    container "wave.seqera.io/wt/b73ba3a93c0e/wave/build:7541bf8cdb9f5a40" //Quick fix for the missing ps tool, see the accompanying Dockerfile

    input:// TODO nf-core: Where applicable all sample-specific information e.g. "id", "single_end", "read_group"
    tuple val(meta), path(reads)
    path(lineage_barcodes)
    output:
    tuple val(meta), path("lineage_report.csv"), emit: report
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def subsampling_fraction = params.vibecheck_subsampling_fraction ? '--subsampling_fraction ${params.vibecheck_subsampling_fraction}' : ''
    def skip_subsampling = params.vibecheck_skip_subsampling ? '--no-detect' : ''
    
    """
    vibecheck ${reads[0]} ${reads[1]} \
        --outdir . \
        ${lineage_barcodes} \
        ${subsampling_fraction} \
        ${skip_subsampling}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vibecheck: \$(vibecheck --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    
    touch lineage_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vibecheck: \$(vibecheck --version)
    END_VERSIONS
    """
}
