process BBDUK {
    tag "$meta.id"
    label "process_low"

    container "us-docker.pkg.dev/general-theiagen/staphb/bbtools:38.76"

    input:
    tuple val(meta), path(read1_trimmed), path(read2_trimmed)
    path adapters
    path phix

    output:
    tuple val(meta), path("*.clean.fastq.gz"), emit: cleaned_reads
    tuple val(meta), path("*.adapters.stats.txt"), emit: adapter_stats
    tuple val(meta), path("*.phix.stats.txt"), emit: phix_stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bbduk_adapters = adapters ?: ""
    def bbduk_phix = phix ?: ""
    
    """
    # date and version control
    date | tee DATE
    
    # set adapter fasta
    if [[ ! -z "${bbduk_adapters}"  ]]; then
        echo "Using user supplied FASTA file for adapters: ${adapters}"
        adapter_fasta="${bbduk_adapters}"
    else
        echo "User did not supply adapters FASTA file, using default adapters.fa file..."
        adapter_fasta="/bbmap/resources/adapters.fa" 
    fi
    
    # set phix fasta
    if [[ ! -z "${bbduk_phix}" ]]; then
        echo "Using user supplied FASTA file for phiX: ${bbduk_phix}"
        phix_fasta="${bbduk_phix}"
    else
        echo "User did not supply phiX FASTA file, using default phix174_ill.ref.fa.gz file..."
        phix_fasta="/bbmap/resources/phix174_ill.ref.fa.gz"
    fi
    
    # Repair reads to ensure proper pairing
    repair.sh \\
        in1=${read1_trimmed} \\
        in2=${read2_trimmed} \\
        out1=${prefix}.paired_1.fastq.gz \\
        out2=${prefix}.paired_2.fastq.gz
    
    # Remove adapters
    bbduk.sh \\
        in1=${prefix}.paired_1.fastq.gz \\
        in2=${prefix}.paired_2.fastq.gz \\
        out1=${prefix}.rmadpt_1.fastq.gz \\
        out2=${prefix}.rmadpt_2.fastq.gz \\
        ref=\${adapter_fasta} \\
        stats=${prefix}.adapters.stats.txt \\
        ktrim=r \\
        k=23 \\
        mink=11 \\
        hdist=1 \\
        tpe \\
        tbo \\
        ordered=t
    
    # Remove PhiX contamination
    bbduk.sh \\
        in1=${prefix}.rmadpt_1.fastq.gz \\
        in2=${prefix}.rmadpt_2.fastq.gz \\
        out1=${prefix}_1.clean.fastq.gz \\
        out2=${prefix}_2.clean.fastq.gz \\
        outm=${prefix}.matched_phix.fq \\
        ref=\${phix_fasta} \\
        k=31 \\
        hdist=1 \\
        stats=${prefix}.phix.stats.txt \\
        ordered=t

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbtools: \$(bbversion.sh)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_1.clean.fastq.gz
    touch ${prefix}_2.clean.fastq.gz
    touch ${prefix}.adapters.stats.txt
    touch ${prefix}.phix.stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbtools: 38.76
    END_VERSIONS
    """
}