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
    tuple val(meta), path("results/*.results.json"), path("bam/*.bam"), path("bam/*.bam.bai"), emit: tbparser_inputs
    tuple val(meta), path("vcf/*.targets.csq.merged.vcf"), optional: true, emit: vcf
    tuple val(meta), path("*_value.txt"), emit: tbprofiler_value_results
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read1 = "-1 ${reads[0]}"
    def read2 = reads.size() > 1 ? "-2 ${reads[1]}" : null
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
      ${read1} \\
      ${read2} \\
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

    # merge all vcf files if multiple are present
    if [ -f ./vcf/*.bcf ] && [ -f ./vcf/*.gz ]; then
      bcftools index ./vcf/*.bcf
      bcftools index ./vcf/*.gz
      bcftools merge --force-samples ./vcf/*.bcf ./vcf/*.gz > ./vcf/${prefix}.targets.csq.merged.vcf
    else
      bcftools index ./vcf/*.gz
      bcftools merge --force-samples --force-single ./vcf/*.gz > ./vcf/${prefix}.targets.csq.merged.vcf
    fi

    parse_tbprofiler.py --input_file ${prefix}.txt

    mv MAIN_LINEAGE.txt tbprofiler_MAIN_LINEAGE_value.txt
    mv SUB_LINEAGE.txt tbprofiler_SUB_LINEAGE_value.txt
    mv DR_TYPE.txt tbprofiler_DR_TYPE_value.txt
    mv NUM_DR_VARIANTS.txt tbprofiler_NUM_DR_VARIANTS_value.txt
    mv NUM_OTHER_VARIANTS.txt tbprofiler_NUM_OTHER_VARIANTS_value.txt
    mv RESISTANCE_GENES.txt tbprofiler_RESISTANCE_GENES_value.txt
    mv MEDIAN_DEPTH.txt tbprofiler_MEDIAN_DEPTH_value.txt
    mv PCT_READS_MAPPED.txt tbprofiler_PCT_READS_MAPPED_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tbprofiler: \$(cat VERSION)
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
    touch MAIN_LINEAGE.txt
    touch SUB_LINEAGE.txt
    touch DR_TYPE.txt
    touch NUM_DR_VARIANTS.txt
    touch NUM_OTHER_VARIANTS.txt
    touch RESISTANCE_GENES.txt
    touch MEDIAN_DEPTH.txt
    touch PCT_READS_MAPPED.txt
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tbprofiler: \$(cat VERSION)
    END_VERSIONS
    """
}