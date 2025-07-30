process TBP_PARSER {
    tag "${meta.id}"
    label 'process_single'

    container "us-docker.pkg.dev/general-theiagen/theiagen/tbp-parser:2.4.5"

    input:
    tuple val(meta), path(json), path(bam), path(bai)
    val config
    val sequencing_method
    val operator
    val min_depth
    val min_frequency
    val min_read_support
    val min_percent_coverage
    val coverage_regions_bed
    val add_cycloserine_lims
    val tbp_parser_debug
    val tngs_data
    val rrs_frequency
    val rrs_read_support
    val rr1_frequency
    val rr1_read_support
    val rpob499_frequency
    val etha237_frequency
    val expert_rule_regions_bed

    output:
    tuple val(meta), path("*.looker_report.csv"), emit: looker_report
    tuple val(meta), path("*.laboratorian_report.csv"), emit: laboratorian_report
    tuple val(meta), path("*.lims_report.csv"), emit: lims_report
    tuple val(meta), path("*.percent_gene_coverage.csv"), emit: coverage_report
    tuple val(meta), path ("*_value.txt"), emit: tbp_parser_value_results
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def config_file = config ?: ""
    def seq_method = sequencing_method ? "--sequencing_method ${sequencing_method}" : ""
    def op_name = operator ? "--operator ${operator}" : ""
    def min_depth_value = min_depth ? "--min_depth ${min_depth}" : ""
    def min_freq_value = min_frequency ? "--min_frequency ${min_frequency}": ""
    def min_read_support_value = min_read_support ? "--min_read_support ${min_read_support}": ""
    def min_cov_value = min_percent_coverage ? "--min_percent_coverage ${min_percent_coverage}": ""
    def coverage_bed = coverage_regions_bed ?: ""
    def add_cycloserine = add_cycloserine_lims ? "--add_cs_lims" : ""
    def debug_mode = tbp_parser_debug ? "--debug": "--verbose"
    def tngs = tngs_data ? "--tngs" : ""
    def rrs_freq = rrs_frequency ? "--rrs_frequency ${rrs_frequency}": ""
    def rrs_read_sup = rrs_read_support ? "--rrs_read_support ${rrs_read_support}": ""
    def rr1_freq = rr1_frequency ? "--rrl_frequency ${rr1_frequency}": ""
    def rr1_read_sup = rr1_read_support ? "--rrl_read_support ${rr1_read_support}": ""
    def rpob499_freq = rpob499_frequency ? "--rpob449_frequency ${rpob499_frequency}": ""
    def etha237_freq = etha237_frequency ? "--etha237_frequency ${etha237_frequency}": ""
    def expert_bed = expert_rule_regions_bed ? "--tngs_expert_regions ${expert_rule_regions_bed}": ""

    """
    # explicitly set covereage regions bed file defaults for wgs/tngs data
    if [[ -z "${coverage_bed}" ]]; then
      if [[ "${tngs}" == "true" ]]; then
        coverage_regions_bed="/tbp-parser/data/tngs-primer-regions.bed"
      else
        coverage_regions_bed="/tbp-parser/data/tbdb-modified-regions.bed"
      fi
    else
      coverage_regions_bed="${coverage_bed}"
    fi

    # get version
    python3 /tbp-parser/tbp_parser/tbp_parser.py --version | tee VERSION

    # run tbp-parser
    python3 /tbp-parser/tbp_parser/tbp_parser.py ${json} ${bam} \\
      ${config_file} \\
      ${seq_method} \\
      ${op_name} \\
      ${min_depth_value} \\
      ${min_freq_value} \\
      ${min_read_support_value} \\
      ${min_cov_value} \\
      --coverage_regions \$coverage_regions_bed \\
      ${expert_bed} \\
      ${rrs_freq} \\
      ${rrs_read_sup} \\
      ${rr1_freq} \\
      ${rr1_read_sup} \\
      ${rpob499_freq} \\
      ${etha237_freq} \\
      --output_prefix ${prefix} \\
      ${debug_mode} \\
      ${tngs} \\
      ${add_cycloserine}

    # set default genome percent coverage and average depth to 0 to prevent failures
    touch GENOME_PC.txt
    touch AVG_DEPTH.txt

    if [[ "${tngs}" == "true" ]]; then
      # get cumulative percent coverage for all primer regions over min_depth
      cumulative_primer_region_length=\$(samtools depth -a -J ${bam} -b "\$coverage_regions_bed" | wc -l)
      genome=\$(samtools depth -a -J ${bam} -b "\$coverage_regions_bed" | awk -F "\\t" -v min_depth=${min_depth} '{if (\$3 >= min_depth) print;}' | wc -l )
      python3 -c "print ( (\$genome / \$cumulative_primer_region_length ) * 100 )" >> GENOME_PC_value.txt
      # get average depth for all primer regions
      samtools depth -a -J ${bam} -b "\$coverage_regions_bed" | awk -F "\\t" '{sum+=\$3} END { if (NR > 0) print sum/NR; else print 0 }' >> AVG_DEPTH_value.txt
    else
      # get genome percent coverage for the entire reference genome length over min_depth
      genome=\$(samtools depth -a -J ${bam} | awk -F "\\t" -v min_depth=${min_depth} '{if (\$3 >= min_depth) print;}' | wc -l )
      python3 -c "print ( (\$genome / 4411532 ) * 100 )" >> GENOME_PC_value.txt
      # get genome average depth
      samtools depth -a -J ${bam} | awk -F "\\t" '{sum+=\$3} END { if (NR > 0) print sum/NR; else print 0 }' >> AVG_DEPTH_value.txt
    fi

    # add sample id to the beginning of the coverage report
    awk '{s=(NR==1)?"Sample_accession_number,":"${prefix},"; \$0=s\$0}1' ${prefix}.percent_gene_coverage.csv > tmp.csv && mv -f tmp.csv ${prefix}.percent_gene_coverage.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_profiler: \$(tb-profiler version | sed 's/TBProfiler version //')
    END_VERSIONS
    """
    
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "This is a stub for TBP_PARSER process."
    touch ${prefix}.looker_report.csv
    touch ${prefix}.laboratorian_report.csv
    touch ${prefix}.lims_report.csv
    touch ${prefix}.percent_gene_coverage.csv
    touch GENOME_PC.txt
    touch AVG_DEPTH.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_profiler: \$(tb-profiler version | sed 's/TBProfiler version //')
    END_VERSIONS
    """
}