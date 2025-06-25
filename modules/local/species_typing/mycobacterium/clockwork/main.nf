process CLOCKWORK_DECON_READS {
    tag "$meta.id"
    label 'process_high'

    container "us-docker.pkg.dev/general-theiagen/cdcgov/varpipe_wgs_with_refs:2bc7234074bd53d9e92a1048b0485763cd9bbf6f4d12d5a1cc82bfec8ca7d75e"

    input:
    tuple val(meta), path(reads)
    
    output:
    tuple val(meta), path("*.fastq.gz"), emit: cleaned_reads
    path "versions.yml", emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read1 = reads[0]
    def read2 = reads.size() > 1 ? reads[1] : null

    """
    # Print and save version
    clockwork version > VERSION

    # Map reads to the clockwork reference
    clockwork map_reads \\
      --unsorted_sam ${prefix} \\
      /varpipe_wgs/tools/clockwork-0.11.3/OUT/ref.fa \\
      "${prefix}.sam" \\
      ${read1} \\
      ${read2}

    # Remove contaminants (reads that map with high identity to non-MTB sequences)
    clockwork remove_contam \\
      /varpipe_wgs/tools/clockwork-0.11.3/OUT/remove_contam_metadata.tsv \\
      "${prefix}.sam" \\
      "${prefix}_outfile_read_counts" \\
      "clockwork_cleaned_${prefix}_R1.fastq.gz" \\
      "clockwork_cleaned_${prefix}_R2.fastq.gz"

    # Clean up files
    rm "${prefix}.sam"
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clockwork_decon_reads: \$(clockwork version)
    END_VERSIONS
    """
    
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read1 = reads[0]
    def read2 = reads.size() > 1 ? reads[1] : null
    """
    mv ${read1} clockwork_cleaned_${prefix}_R1.fastq.gz
    mv ${read2} clockwork_cleaned_${prefix}_R2.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clockwork_decon_reads: \$(clockwork version)
    END_VERSIONS
    """
}