process TS_MLST {
    tag "$meta.id"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "us-docker.pkg.dev/general-theiagen/staphb/mlst:2.23.0-2024-12-31"

    input:
    tuple val(meta), path(assembly)
    val nopath
    val scheme
    val taxonomy
    val min_percent_identity
    val min_percent_coverage
    val minscore

    output:
    tuple val(meta), path("*_ts_mlst.tsv"), emit: ts_mlst_results
    tuple val(meta), path("*_value.txt"), emit: ts_mlst_value_results
    tuple val(meta), path("*_novel_mlst_alleles.fasta"), optional: true, emit: novel_alleles
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Determine if nopath is true or false
    if (nopath) {
        // If nopath is true, remove the path from the assembly file
        nopath_arg = "--nopath"
    } else {
        nopath_arg = ""
    }
    def scheme_arg = scheme ? "--scheme ${scheme}" : ""
    def minid_arg = min_percent_identity ? "--minid ${min_percent_identity}" : ""
    def mincov_arg = min_percent_coverage ? "--mincov ${min_percent_coverage}" : ""
    def minscore_arg = minscore ? "--minscore ${minscore}" : ""
    def taxonomy_val = taxonomy ?: ""
    
    """
    # If else checks for schemes of ecoli and taxon are for shortcomings in the mlst tool
    # found from adapting theiaprok for ARLN functionality.
    # CDCs mlst container, used by OH, also houses ecoli_2 scheme whereas Staphb does not, hence the check of if ecoli_2 is in the DB
    # exists on lines 59 and 92.
    
    #create output header
    echo -e "Filename\\tPubMLST_Scheme_name\\tSequence_Type_(ST)\\tAllele_IDs" > ${prefix}_ts_mlst.tsv

    mlst --list > MLST_SCHEMES

    mlst \\
      --threads ${task.cpus} \\
      ${nopath_arg} \\
      ${scheme_arg} \\
      ${minid_arg} \\
      ${mincov_arg} \\
      ${minscore_arg} \\
      --novel ${prefix}_novel_mlst_alleles.fasta \\
      ${assembly} \\
      ${args} \\
      >> ${prefix}_ts_mlst.tsv

    scheme=\$(head -n 2 ${prefix}_ts_mlst.tsv | tail -n 1 | cut -f2)
    echo "Scheme Initial Run: \$scheme"

    if [[ "\$scheme" == "ecoli" || "\$scheme" == "ecoli_2" || "\$scheme" == "abaumannii" || "\$scheme" == "abaumannii_2" ]]; then
      cp ${prefix}_ts_mlst.tsv ${prefix}_1.tsv
      secondary_scheme=\$(if [[ "\$scheme" == *_2 ]]; then echo "\${scheme%_2}"; else echo "\${scheme}_2"; fi)

      # Check if secondary scheme is in DB
      if grep -q "\$secondary_scheme" MLST_SCHEMES; then
        mlst \\
          --threads ${task.cpus} \\
          ${nopath_arg} \\
          --scheme \$secondary_scheme \\
          ${minid_arg} \\
          ${mincov_arg} \\
          ${minscore_arg} \\
          --novel ${prefix}_novel_mlst_alleles_\${secondary_scheme}.fasta \\
          ${assembly} \\
          ${args} \\
          >> ${prefix}_2.tsv

        cat ${prefix}_1.tsv ${prefix}_2.tsv > ${prefix}_ts_mlst.tsv
        cat ${prefix}_novel_mlst_alleles_\${secondary_scheme}.fasta ${prefix}_novel_mlst_alleles.fasta > ${prefix}_novel_mlst_alleles.fasta
      fi

    elif [[ "${taxonomy_val}" == "Escherichia" || "${taxonomy_val}" == "Escherichia coli" || "${taxonomy_val}" == "Escherichia_coli" ]]; then
      if [[ "\$scheme" == "aeromonas" || "\$scheme" == "cfreundii" ||  "\$scheme" == "senterica" ]]; then
          echo "Taxonomy is reported as Escherichia, but scheme is not. Running ecoli schemes."

          mlst \\
            --threads ${task.cpus} \\
            ${nopath_arg} \\
            --scheme ecoli \\
            ${minid_arg} \\
            ${mincov_arg} \\
            ${minscore_arg} \\
            --novel ${prefix}_novel_mlst_alleles.fasta \\
            ${assembly} \\
            ${args} \\
            >> ${prefix}_1.tsv

          # Check if secondary scheme is in DB
          if grep -q ecoli_2 MLST_SCHEMES; then
            mlst \\
              --threads ${task.cpus} \\
              ${nopath_arg} \\
              --scheme ecoli_2 \\
              ${minid_arg} \\
              ${mincov_arg} \\
              ${minscore_arg} \\
              --novel ${prefix}_novel_mlst_alleles_2.fasta \\
              ${assembly} \\
              ${args} \\
              >> ${prefix}_2.tsv

            #create output header
            echo -e "Filename\\tPubMLST_Scheme_name\\tSequence_Type_(ST)\\tAllele_IDs" > ${prefix}_ts_mlst.tsv

            cat ${prefix}_1.tsv ${prefix}_2.tsv >> ${prefix}_ts_mlst.tsv
            cat ${prefix}_novel_mlst_alleles.fasta ${prefix}_novel_mlst_alleles_2.fasta > ${prefix}_novel_mlst_alleles.fasta
          else
            echo -e "Filename\\tPubMLST_Scheme_name\\tSequence_Type_(ST)\\tAllele_IDs" > ${prefix}_ts_mlst.tsv
            cat ${prefix}_1.tsv >> ${prefix}_ts_mlst.tsv
          fi
      fi
    fi
    
    # parse ts mlst tsv for relevant outputs
    # if output TSV only contains one line (header line); no ST predicted
    if [ \$(wc -l ${prefix}_ts_mlst.tsv | awk '{ print \$1 }') -eq 1 ]; then
      predicted_mlst="No ST predicted"
      pubmlst_scheme="NA"
      allelic_profile="NA"
    # else, TSV has 3 lines, so parse outputs, occurs when two schemes were run and concatenated
    elif [ \$(wc -l ${prefix}_ts_mlst.tsv | awk '{ print \$1 }') -eq 3 ]; then
      # Extract the schemes from both rows, excluding header, if not equal to "-" or "ST-", and join them with a comma.
      # These extractions are only performed if the ST type is reported.
      pubmlst_scheme="\$(awk -F'\\t' 'NR>1 && \$2!="-" && \$3~/[0-9]/ {print \$2}' ${prefix}_ts_mlst.tsv | paste -sd ', ' -)"
      predicted_mlst="\$(awk -F'\\t' 'NR>1 && \$3~/[0-9]/ {print "ST"\$3}' ${prefix}_ts_mlst.tsv | paste -sd ', ' -)"
      # Due to alleles being on different columns, we need to pull all columns from the 4th column to the end, join with comma, 
      # and replace tabs with commas as we iterate
      allelic_profile="\$(awk -F'\\t' 'NR>1 && \$3~/[0-9]/ {for(i=4; i<=NF; i++) printf("%s%s", \$i, (i<NF ? "," : "\\n"))}' ${prefix}_ts_mlst.tsv | paste -sd ', ' -)"

    # else, TSV has 2 lines, parse outputs
    else
      pubmlst_scheme="\$(cut -f2 ${prefix}_ts_mlst.tsv | tail -n 1)"
      predicted_mlst="ST\$(cut -f3 ${prefix}_ts_mlst.tsv | tail -n 1)"
      # allelic_profile: take second line of output TSV; cut to take 4th column and beyond; replace tabs with commas
      allelic_profile="\$(cut -f 4- ${prefix}_ts_mlst.tsv | tail -n 1 | sed -e 's|\\t|,|g')"
      if [ "\$pubmlst_scheme" == "-" ]; then
        predicted_mlst="No ST predicted"
        pubmlst_scheme="NA"
        allelic_profile="NA"
      else
        if [ "\$predicted_mlst" == "ST-" ]; then
        predicted_mlst="No ST predicted"
        fi
      fi
    fi
    
    echo "\$predicted_mlst" > PREDICTED_MLST_value.txt
    echo "\$pubmlst_scheme" > PUBMLST_SCHEME_value.txt
    echo "\$allelic_profile" > ALLELIC_PROFILE_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$(mlst --version 2>&1 | sed 's/mlst //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_ts_mlst.tsv
    touch ${prefix}_novel_mlst_alleles.fasta
    echo "No ST predicted" > PREDICTED_MLST_value.txt
    echo "NA" > PUBMLST_SCHEME_value.txt
    echo "NA" > ALLELIC_PROFILE_value.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$(mlst --version 2>&1 | sed 's/mlst //')
    END_VERSIONS
    """
}