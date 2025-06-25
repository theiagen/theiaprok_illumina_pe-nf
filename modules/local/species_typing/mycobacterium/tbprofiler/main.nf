process TBPROFILER {
    tag "$meta.id"
    label 'process_medium'

    container "us-docker.pkg.dev/general-theiagen/staphb/tbprofiler:6.6.3"

    input:
    tuple val(meta), path(reads)
    val ont_data // set to false if not ONT data, Theiaprok_Illumina_PE/SE/FASTA

    output:
    tuple val(meta), path("results/*.results.csv"), emit: csv
    tuple val(meta), path("results/*.results.txt"), emit: txt
    tuple val(meta), path("results/*.results.json"), emit: json
    tuple val(meta), path("bam/*.bam"), emit: bam
    tuple val(meta), path("bam/*.bam.bai"), emit: bai
    tuple val(meta), path("vcf/*.targets.csq.merged.vcf"), optional: true, emit: vcf
    tuple val(meta), path("VERSION"), emit: version
    tuple val(meta), path("MAIN_LINEAGE"), emit: main_lineage
    tuple val(meta), path("SUB_LINEAGE"), emit: sub_lineage
    tuple val(meta), path("DR_TYPE"), emit: dr_type
    tuple val(meta), path("NUM_DR_VARIANTS"), emit: num_dr_variants
    tuple val(meta), path("NUM_OTHER_VARIANTS"), emit: num_other_variants
    tuple val(meta), path("RESISTANCE_GENES"), emit: resistance_genes
    tuple val(meta), path("MEDIAN_DEPTH"), emit: median_depth
    tuple val(meta), path("PCT_READS_MAPPED"), emit: pct_reads_mapped

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read1 = reads[0]
    def read2 = reads.size() > 1 ? reads[1] : null
    def is_ont = ont_data ? "--platform nanopore": ""
    def variant_caller = params.tbprofiler_variant_caller ?: "gatk"
    def variant_calling_params = params.tbprofiler_variant_calling_params ?: ""
    def min_depth = params.tbprofiler_min_depth ?: 10
    def min_af = params.tbprofiler_min_af ?: 0.1
    def tbprofiler_custom_db = params.tbprofiler_custom_db ?: ""
    def tbprofiler_run_custom_db = params.tbprofiler_run_custom_db ?: false
    def tbprofiler_run_cdph_db = params.tbprofiler_run_cdph_db ?: false
    def tbprofiler_mapper = params.tbprofiler_mapper ?: "bwa"
    def args = task.ext.args ?: ""

    """
    # Print and save version
    tb-profiler version > VERSION && sed -i -e 's/TBProfiler version //' VERSION && sed -n -i '\$p' VERSION
    
    # check if file is non existant or non empty
    if [ -z "${read2}" ] || [ ! -s "${read2}" ]; then
      INPUT_READS="-1 ${read1}"
    else
      INPUT_READS="-1 ${read1} -2 ${read2}"
    fi

    # check if new database file is provided and not empty
    TBDB=""
    if ${tbprofiler_run_custom_db}; then
      if [ ! -s ${tbprofiler_custom_db} ]; then
        echo "Custom database file is empty"
      else
        echo "Found new database file ${tbprofiler_custom_db}"
        prefix=\$(basename "${tbprofiler_custom_db}" | sed 's/\\.tar\\.gz\$//')
        tar xfv ${tbprofiler_custom_db}
        
        tb-profiler load_library ./"\$prefix"/"\$prefix"

        TBDB="--db \$prefix"
      fi
    elif ${tbprofiler_run_cdph_db}; then
      tb-profiler update_tbdb --branch CaliforniaDPH
      TBDB="--db CaliforniaDPH"
    fi

    # Run tb-profiler on the input reads with prefix prefix
    tb-profiler profile \\
      ${read1} ${read2} \\
      --prefix ${prefix} \\
      --mapper ${tbprofiler_mapper} \\
      --caller ${variant_caller} \\
      --calling_params "${variant_calling_params}" \\
      --depth ${min_depth} \\
      --af ${min_af} \\
      --threads ${task.cpus} \\
      --csv --txt \\
      ${is_ont} \\
      ${args} \\
      \${TBDB}

    # Collate results
    tb-profiler collate --prefix ${prefix}
    ls -la ./*/*
    # merge all vcf files if multiple are present
    bcftools index ./vcf/*.bcf
    bcftools index ./vcf/*.gz
    bcftools merge --force-samples ./vcf/*.bcf ./vcf/*.gz > ./vcf/${prefix}.targets.csq.merged.vcf
    
    parse_tbprofiler.py --input_file results/${prefix}.results.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tbprofiler: \$(VERSION)
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Create empty files for stub
    tb-profiler version > VERSION && sed -i -e 's/TBProfiler version //' VERSION && sed -n -i '\$p' VERSION
    mkdir results bam vcf
    touch results/${prefix}.results.csv
    touch results/${prefix}.results.txt
    touch results/${prefix}.results.json
    touch bam/${prefix}.bam
    touch bam/${prefix}.bam.bai
    touch vcf/${prefix}.targets.csq.merged.vcf
    echo "na" > MAIN_LINEAGE
    echo "na" > SUB_LINEAGE
    echo "na" > DR_TYPE
    echo "na" > NUM_DR_VARIANTS
    echo "na" > NUM_OTHER_VARIANTS
    echo "na" > RESISTANCE_GENES
    echo "na" > MEDIAN_DEPTH
    echo "na" > PCT_READS_MAPPED
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tbprofiler: \$(VERSION)
    END_VERSIONS
    """
}