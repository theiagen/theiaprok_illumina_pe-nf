process PILON {
    tag "$meta.id"
    label "process_medium"
    
    container "us-docker.pkg.dev/general-theiagen/biocontainers/pilon:1.24--hdfd78af_0"

    input:
    tuple val(meta), path(assembly), path(bam), path(bai)

    output:
    tuple val(meta), path('*.fasta')   , emit: improved_assembly
    tuple val(meta), path('*.changes') , emit: changes
    tuple val(meta), path('*.vcf')     , emit: vcf
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def valid_fix = ['all', 'bases', 'gaps', 'local', 'snps', 'indels', 'amb', 'breaks', 'circles', 'novel']
    def fix = params.pilon_fix in valid_fix ? params.pilon_fix : 'bases'
    def min_mapping_quality = params.pilon_min_mapping_quality ?: 60
    def min_base_quality = params.pilon_min_base_quality ?: 3
    def min_depth = params.pilon_min_depth ?: 0.25
    
    """
    pilon \\
        --genome ${assembly} \\
        --frags ${bam} \\
        --output ${prefix} \\
        --outdir pilon \\
        --changes \\
        --vcf \\
        --minmq ${min_mapping_quality} \\
        --minqual ${min_base_quality} \\
        --mindepth ${min_depth} \\
        --fix ${fix} \\
        ${args}

    mv pilon/${prefix}.fasta ${prefix}_pilon.fasta
    mv pilon/${prefix}.changes ${prefix}_pilon.changes
    mv pilon/${prefix}.vcf ${prefix}_pilon.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pilon: \$(pilon --version 2>&1 | sed 's/^.*Pilon version //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_pilon.fasta
    touch ${prefix}_pilon.changes
    touch ${prefix}_pilon.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pilon: \$(pilon --version 2>&1 | sed 's/^.*Pilon version //; s/ .*\$//')
    END_VERSIONS
    """
}