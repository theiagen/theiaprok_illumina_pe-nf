process STXTYPER {
    tag "${meta.id}"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/staphb/stxtyper:1.0.42"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*_stxtyper.tsv"), emit: stxtyper_report
    tuple val(meta), path("*_stxtyper.log"), emit: stxtyper_log
    tuple val(meta), path("*_value.txt"), emit: stxtyper_value_results
    path "versions.yml", emit: stxtyper_version

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def enable_debugging = params.stxtyper_enable_debugging ? "--debug" : ""

    """
    # fail task if any commands below fail since there's lots of bash conditionals below (AGH!)
    set -eo pipefail

    # capture version info
    stxtyper --version | tee VERSION.txt

    # NOTE: by default stxyper uses \$TMPDIR or /tmp, so if we run into issues we may need to adjust in the future. Could potentially use PWD as the TMPDIR.
    #echo "DEBUG: TMPDIR is set to: \$TMPDIR"

    echo "DEBUG: running StxTyper now..."
    # run StxTyper on assembly; may need to add/remove options in the future if they change
    # NOTE: stxtyper can accept gzipped assemblies, so no need to unzip
    stxtyper \\
      --nucleotide ${assembly} \\
      --name ${prefix} \\
      --output ${prefix}_stxtyper.tsv \\
      ${'--threads ' + task.cpus} \\
      ${enable_debugging} \\
      --log ${prefix}_stxtyper.log

    # parse output TSV
    echo "DEBUG: Parsing StxTyper output TSV..."

    # check for output file with only 1 line (meaning no hits found); exit cleanly if so
    if [ "\$(wc -l < ${prefix}_stxtyper.tsv)" -eq 1 ]; then
      echo "No hits found by StxTyper" > stxtyper_hits_value.txt
      echo "0" > stxtyper_num_hits_value.txt
      echo "DEBUG: No hits found in StxTyper output TSV. Exiting task with exit code 0 now."
      
      # create empty output files
      touch stxtyper_all_hits_value.txt stxtyper_complete_operons_value.txt stxtyper_partial_hits_value.txt stxtyper_stx_frameshifts_or_internal_stop_hits_value.txt  stx_novel_hits_value.txt stxtyper_extended_operons_value.txt stxtyper_ambiguous_hits_value.txt
      # put "none" into all of them so task does not fail
      echo "None" | tee stxtyper_all_hits_value.txt stxtyper_complete_operons_value.txt stxtyper_partial_hits_value.txt stxtyper_stx_frameshifts_or_internal_stop_hits_value.txt stx_novel_hits_value.txt stxtyper_extended_operons_value.txt stxtyper_ambiguous_hits_value.txt
    fi
    
    # check for output file with more than 1 line (meaning hits found); count lines & parse output TSV if so
    if [ "\$(wc -l < ${prefix}_stxtyper.tsv)" -gt 1 ]; then
      echo "Hits found by StxTyper. Counting lines & parsing output TSV now..."
      # count number of lines in output TSV (excluding header)
      wc -l < ${prefix}_stxtyper.tsv | awk '{print \$1-1}' > stxtyper_num_hits_value.txt
      # remove header line
      sed '1d' ${prefix}_stxtyper.tsv > ${prefix}_stxtyper_noheader.tsv

      ##### parse output TSV #####
      ### complete operons
      echo "DEBUG: Parsing complete operons..."
      awk -F'\\t' -v OFS=, '\$4 == "COMPLETE" {print \$3}' ${prefix}_stxtyper.tsv | paste -sd, - > stxtyper_complete_operons_value.txt
      # if grep for COMPLETE fails, write "None" to file for output string
      if [[ "\$(grep --silent 'COMPLETE' ${prefix}_stxtyper.tsv; echo \$?)" -gt 0 ]]; then
        echo "None" > stxtyper_complete_operons_value.txt
      fi

      ### complete_novel operons
      echo "DEBUG: Parsing complete novel hits..."
      if [ "\$(grep --silent 'COMPLETE_NOVEL' ${prefix}_stxtyper.tsv; echo \$?)" -gt 0 ]; then
        awk -F'\\t' -v OFS=, '\$4 == "COMPLETE_NOVEL" {print \$3}' ${prefix}_stxtyper.tsv | paste -sd, - > stx_novel_hits_value.txt
      else    
        # if grep for COMPLETE_NOVEL fails, write "None" to file for output string
        echo "None" > stx_novel_hits_value.txt
      fi

      ### partial hits (to any gene in stx operon)
      echo "DEBUG: Parsing stxtyper partial hits..."
      # explanation: if "operon" column contains "PARTIAL" (either PARTIAL or PARTIAL_CONTIG_END possible); print either "stx1" or "stx2" or "stx1,stx2"
      if [ "\$(grep --silent 'stx' stxtyper_partial_hits_value.txt; echo \$?)" -gt 0 ]; then
        awk -F'\\t' -v OFS=, '\$4 ~ "PARTIAL.*" {print \$3}' ${prefix}_stxtyper.tsv | sort | uniq | paste -sd, - > stxtyper_partial_hits_value.txt
      else
        # if no stx partial hits found, write "None" to file for output string
        echo "None" > stxtyper_partial_hits_value.txt
      fi

      ### frameshifts or internal stop codons in stx genes
      echo "DEBUG: Parsing stx frameshifts or internal stop codons..."
      # explanation: if operon column contains "FRAME_SHIFT" or "INTERNAL_STOP", print the "operon" in a sorted/unique list
      if [ "\$(grep --silent -E 'FRAMESHIFT|INTERNAL_STOP' ${prefix}_stxtyper.tsv; echo \$?)" -gt 0 ]; then
        awk -F'\\t' -v OFS=, '\$4 == "FRAMESHIFT" || \$4 == "INTERNAL_STOP" {print \$3}' ${prefix}_stxtyper.tsv | sort | uniq | paste -sd, - > stxtyper_stx_frameshifts_or_internal_stop_hits_value.txt
      else  
        # if no frameshifts or internal stop codons found, write "None" to file for output string
        echo "None" > stxtyper_stx_frameshifts_or_internal_stop_hits_value.txt
      fi

      ### extended operons
      echo "DEBUG: Parsing extended operons..."
      if [ "\$(grep --silent 'EXTENDED' ${prefix}_stxtyper.tsv; echo \$?)" -gt 0 ]; then
        awk -F'\\t' -v OFS=, '\$4 == "EXTENDED" {print \$3}' ${prefix}_stxtyper.tsv | paste -sd, - > stxtyper_extended_operons_value.txt
      else
        echo "None" > stxtyper_extended_operons_value.txt
      fi

      ### ambiguous hits
      echo "DEBUG: Parsing ambiguous hits..."
      if [ "\$(grep --silent 'AMBIGUOUS' ${prefix}_stxtyper.tsv; echo \$?)" -gt 0 ]; then
        awk -F'\\t' -v OFS=, '\$4 == "AMBIGUOUS" {print \$3}' ${prefix}_stxtyper.tsv | paste -sd, - > stxtyper_ambiguous_hits_value.txt
      else
        echo "None" > stxtyper_ambiguous_hits_value.txt
      fi
      
      echo "DEBUG: generating stx_type_all string output now..."
      # sort and uniq so there are no duplicates; then paste into a single comma-separated line with commas
      # sed is to remove any instances of "None" from the output
      cat stxtyper_complete_operons_value.txt stxtyper_partial_hits_value.txt stxtyper_stx_frameshifts_or_internal_stop_hits_value.txt stx_novel_hits_value.txt stxtyper_extended_operons_value.txt stxtyper_ambiguous_hits_value.txt | sed '/None/d' | sort | uniq | paste -sd, - > stxtyper_all_hits_value.txt

    fi
    echo "DEBUG: Finished parsing StxTyper output TSV."

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stxtyper: \$(cat VERSION.txt)
    END_VERSIONS
    """
    
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "na" > "${prefix}_stxtyper.tsv"
    echo "na" > "${prefix}_stxtyper.log"
    echo "na" > stxtyper_num_hits_value.txt
    echo "na" > stxtyper_all_hits_value.txt
    echo "na" > stxtyper_complete_operons_value.txt
    echo "na" > stxtyper_partial_hits_value.txt
    echo "na" > stxtyper_stx_frameshifts_or_internal_stop_hits_value.txt
    echo "na" > stx_novel_hits_value.txt
    echo "na" > stxtyper_extended_operons_value.txt
    echo "na" > stxtyper_ambiguous_hits_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stxtyper: \$(stxtyper --version)
    END_VERSIONS
    """
}