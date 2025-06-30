process AMRFINDER_PLUS_NUC {
    tag "${meta.id}"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/staphb/ncbi-amrfinderplus:4.0.23-2025-06-03.1"

    input:
    tuple val(meta), path(assembly)
    val organism
    output:
    tuple val(meta), path("*_amrfinder_all.tsv"), emit: amrfinderplus_all_report
    tuple val(meta), path("*_amrfinder_amr.tsv"), emit: amrfinderplus_amr_report
    tuple val(meta), path("*_amrfinder_stress.tsv"), emit: amrfinderplus_stress_report
    tuple val(meta), path("*_amrfinder_virulence.tsv"), emit: amrfinderplus_virulence_report
    tuple val(meta), path("*_values.txt"), emit: amrfinderplus_value_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def organism_arg = organism ? "--organism ${organism}" : ""
    def min_percent_identity_arg = params.amrfinder_min_percent_identity ? "--ident_min $params.amrfinder_min_percent_identity" : ""
    def min_percent_coverage_arg = params.amrfinder_min_percent_coverage ? "--coverage_min $params.amrfinder_min_percent_coverage" : ""
    def hide_point_mutations = params.amrfinder_hide_point_mutations ?: false
    def detailed_drug_class = params.amrfinder_detailed_drug_class ?: false
    def separate_betalactam_genes = params.amrfinder_separate_betalactam_genes ?: false

    """
    # logging info
    date | tee DATE

    # Initialize variable to avoid unbound variable error
    amrfinder_organism=""

    ## create associative array
    declare -A organisms=( ["Acinetobacter baumannii"]="Acinetobacter_baumannii" ["Burkholderia cepacia"]="Burkholderia_cepacia" \\
      ["Burkholderia pseudomallei"]="Burkholderia_pseudomallei" ["Campylobacter coli"]="Campylobacter" ["Campylobacter jejuni"]="Campylobacter" \\
      ["Citrobacter freundii"]="Citrobacter_freundii" ["Clostridioides difficile"]="Clostridioides_difficile" ["Enterobacter asburiae"]="Enterobacter_asburiae" ["Enterobacter cloacae"]="Enterobacter_cloacae" \\
      ["Enterococcus faecalis"]="Enterococcus_faecalis" ["Enterococcus hirae"]="Enterococcus_faecium" ["Enterococcusfaecium"]="Enterococcus_faecium" \\
      ["Escherichia"]="Escherichia" ["Shigella"]="Escherichia" ["Klebsiella aerogenes"]="Klebsiella_pneumoniae" ["Klebsiella pneumoniae"]="Klebsiella_pneumoniae" \\
      ["Klebsiella variicola"]="Klebsiella_pneumoniae" ["Klebsiella oxytoca"]="Klebsiella_oxytoca" ["Neisseria gonorrhea"]="Neisseria_gonorrhoeae" \\
      ["Neisseria gonorrhoeae"]="Neisseria_gonorrhoeae" ["Neisseria meningitidis"]="Neisseria_meningitidis" ["Pseudomonas aeruginosa"]="Pseudomonas_aeruginosa" \\
      ["Salmonella"]="Salmonella" ["Serratia marcescens"]="Serratia_marcescens" ["Staphylococcus aureus"]="Staphylococcus_aureus" \\
      ["Staphylococcus pseudintermedius"]="Staphylococcus_pseudintermedius" ["Streptococcus agalactiae"]="Streptococcus_agalactiae" \\
      ["Streptococcus pneumoniae"]="Streptococcus_pneumoniae" ["Streptococcus mitis"]="Streptococcus_pneumoniae" \\
      ["Streptococcus pyogenes"]="Streptococcus_pyogenes" ["Vibrio cholerae"]="Vibrio_cholerae" ["Vibrio parahaemolyticus"]="Vibrio_parahaemolyticus" ["Vibrio vulnificus"]="Vibrio_vulnificus"
      )

    for key in "\${!organisms[@]}"; do
      if [[ "${organism}" == \$key ]]; then
        amrfinder_organism=\${organisms[\$key]}
      elif [[ "${organism}" == *\$key* ]]; then
        amrfinder_organism=\${organisms[\$key]}
      fi
    done

    # checking bash variable
    echo "amrfinder_organism is set to: \${amrfinder_organism}"
    
    # if amrfinder_organism variable has a value, use --organism flag, otherwise do not use --organism flag
    if [[ -n "\${amrfinder_organism}" ]] ; then
      # always use --plus flag, others may be left out if param is optional and not supplied 
      amrfinder --plus \\
        ${organism_arg} \\
        --name ${prefix} \\
        --nucleotide ${assembly} \\
        -o ${prefix}_amrfinder_all.tsv \\
        ${'--threads ' + task.cpus} \\
        ${min_percent_coverage_arg} \\
        ${min_percent_identity_arg} \\
        ${args}
    else 
      echo "Either the organism (${organism}) is not recognized by NCBI-AMRFinderPlus or the user did not supply an organism as input."
      echo "Skipping the use of amrfinder --organism optional parameter."
      # always use --plus flag, others may be left out if param is optional and not supplied 
      amrfinder --plus \\
        --name ${prefix} \\
        --nucleotide ${assembly} \\
        -o ${prefix}_amrfinder_all.tsv \\
        ${'--threads ' + task.cpus} \\
        ${min_percent_coverage_arg} \\
        ${min_percent_identity_arg} \\
        ${args}
    fi

    echo "removing mutations"
    # remove mutations where Element subtype is "POINT"
    if [[ ${hide_point_mutations} == "true" ]]; then
      awk -F "\t" '\$11 != "POINT"' ${prefix}_amrfinder_all.tsv >> temp.tsv
      mv temp.tsv ${prefix}_amrfinder_all.tsv
    fi
    echo "removed mutations"

    # Element Type possibilities: AMR, STRESS, and VIRULENCE 
    # create headers for 3 output files; tee to 3 files and redirect STDOUT to dev null so it doesn't print to log file
    head -n 1 ${prefix}_amrfinder_all.tsv | tee ${prefix}_amrfinder_stress.tsv ${prefix}_amrfinder_virulence.tsv ${prefix}_amrfinder_amr.tsv >/dev/null
    # looks for all rows with STRESS, AMR, or VIRULENCE and append to TSVs
    # || true is so that the final grep exits with code 0, preventing failures
    grep 'STRESS' ${prefix}_amrfinder_all.tsv >> ${prefix}_amrfinder_stress.tsv || true
    grep 'VIRULENCE' ${prefix}_amrfinder_all.tsv >> ${prefix}_amrfinder_virulence.tsv || true
    grep 'AMR' ${prefix}_amrfinder_all.tsv >> ${prefix}_amrfinder_amr.tsv || true
    echo "separated AMR, STRESS, and VIRULENCE genes"

    # create string outputs for all genes identified in AMR, STRESS, VIRULENCE
    amr_core_genes=\$(awk -F '\\t' '{ if(\$9 == "core") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//')
    amr_plus_genes=\$(awk -F '\\t' '{ if(\$9 != "core") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tail -n+2 | tr '\\n' ', ' | sed 's/.\$//')
    stress_genes=\$(awk -F '\\t' '{ print \$7 }' ${prefix}_amrfinder_stress.tsv | tail -n+2 | tr '\\n' ', ' | sed 's/.\$//')
    virulence_genes=\$(awk -F '\\t' '{ print \$7 }' ${prefix}_amrfinder_virulence.tsv | tail -n+2 | tr '\\n' ', ' | sed 's/.\$//')
    
    echo "separating AMR classes and subclasses"
    if [[ ${detailed_drug_class} == "true" ]]; then
      # create string outputs for AMR drug classes
      amr_classes=\$(awk -F '\\t' 'BEGIN{OFS=":"} {print \$7,\$12}' ${prefix}_amrfinder_amr.tsv | tail -n+2 | tr '\\n' ', ' | sed 's/.\$//')
      # create string outputs for AMR drug subclasses
      amr_subclasses=\$(awk -F '\\t' 'BEGIN{OFS=":"} {print \$7,\$13}' ${prefix}_amrfinder_amr.tsv | tail -n+2 | tr '\\n' ', ' | sed 's/.\$//')
    else
      amr_classes=\$(awk -F '\\t' '{ print \$12 }' ${prefix}_amrfinder_amr.tsv | tail -n+2 | sort | uniq | tr '\\n' ', ' | sed 's/.\$//')
      amr_subclasses=\$(awk -F '\\t' '{ print \$13 }' ${prefix}_amrfinder_amr.tsv | tail -n+2 | sort | uniq | tr '\\n' ', ' | sed 's/.\$//')
    fi

    echo "separating genes"
    if [[ ${separate_betalactam_genes} == "true" ]]; then
      betalactam_genes=\$(awk -F '\\t' '{ if(\$12 == "BETA-LACTAM") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//') 
      betalactam_betalactam_genes=\$(awk -F '\\t' '{ if(\$13 == "BETA-LACTAM") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//') 
      betalactam_carbapenem_genes=\$(awk -F '\\t' '{ if(\$13 == "CARBAPENEM") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//')
      betalactam_cephalosporin_genes=\$(awk -F '\\t' '{ if(\$13 == "CEPHALOSPORIN") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//')
      betalactam_cephalothin_genes=\$(awk -F '\\t' '{ if(\$13 == "CEPHALOTHIN") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//')
      betalactam_methicillin_genes=\$(awk -F '\\t' '{ if(\$13 == "METHICILLIN") { print \$7}}' ${prefix}_amrfinder_amr.tsv | tr '\\n' ', ' | sed 's/.\$//')
      
      # if variable for list of genes is EMPTY, write string saying it is empty to float to Terra table
      if [ -z "\${betalactam_genes}" ]; then
        betalactam_genes="No BETA-LACTAM genes detected by NCBI-AMRFinderPlus"
      fi
      if [ -z "\${betalactam_betalactam_genes}" ]; then
        betalactam_betalactam_genes="No BETA-LACTAM genes detected by NCBI-AMRFinderPlus"
      fi
      if [ -z "\${betalactam_carbapenem_genes}" ]; then
        betalactam_carbapenem_genes="No BETA-LACTAM CARBAPENEM genes detected by NCBI-AMRFinderPlus"
      fi
      if [ -z "\${betalactam_cephalosporin_genes}" ]; then
        betalactam_cephalosporin_genes="No BETA-LACTAM CEPHALOSPORIN genes detected by NCBI-AMRFinderPlus"
      fi
      if [ -z "\${betalactam_cephalothin_genes}" ]; then
        betalactam_cephalothin_genes="No BETA-LACTAM CEPHALOTHIN genes detected by NCBI-AMRFinderPlus"
      fi
      if [ -z "\${betalactam_methicillin_genes}" ]; then
        betalactam_methicillin_genes="No BETA-LACTAM METHICILLIN genes detected by NCBI-AMRFinderPlus"
      fi
    else 
        betalactam_genes=""
        betalactam_betalactam_genes=""
        betalactam_carbapenem_genes=""
        betalactam_cephalosporin_genes=""
        betalactam_cephalothin_genes=""
        betalactam_methicillin_genes=""
    fi

    # if variable for list of genes is EMPTY, write string saying it is empty to float to Terra table
    if [ -z "\${amr_core_genes}" ]; then
       amr_core_genes="No core AMR genes detected by NCBI-AMRFinderPlus"
    fi 
    if [ -z "\${amr_plus_genes}" ]; then
       amr_plus_genes="No plus AMR genes detected by NCBI-AMRFinderPlus"
    fi 
    if [ -z "\${stress_genes}" ]; then
       stress_genes="No STRESS genes detected by NCBI-AMRFinderPlus"
    fi 
    if [ -z "\${virulence_genes}" ]; then
       virulence_genes="No VIRULENCE genes detected by NCBI-AMRFinderPlus"
    fi 
    if [ -z "\${amr_classes}" ]; then
       amr_classes="No AMR genes detected by NCBI-AMRFinderPlus"
    fi 
    if [ -z "\${amr_subclasses}" ]; then
       amr_subclasses="No AMR genes detected by NCBI-AMRFinderPlus"
    fi 

    # create final output strings
    echo "\${amr_core_genes}" > AMR_CORE_GENES_values.txt
    echo "\${amr_plus_genes}" > AMR_PLUS_GENES_values.txt
    echo "\${stress_genes}" > STRESS_GENES_values.txt
    echo "\${virulence_genes}" > VIRULENCE_GENES_values.txt
    echo "\${amr_classes}" > AMR_CLASSES_values.txt
    echo "\${amr_subclasses}" > AMR_SUBCLASSES_values.txt
  
    # if separate_betalactam_genes is true, create final output strings (if false, these values will be blank)
    echo "\${betalactam_genes}" > BETA_LACTAM_GENES_values.txt
    echo "\${betalactam_betalactam_genes}" > BETA_LACTAM_BETA_LACTAM_GENES_values.txt
    echo "\${betalactam_carbapenem_genes}" > BETA_LACTAM_CARBAPENEM_GENES_values.txt
    echo "\${betalactam_cephalosporin_genes}" > BETA_LACTAM_CEPHALOSPORIN_GENES_values.txt
    echo "\${betalactam_cephalothin_genes}" > BETA_LACTAM_CEPHALOTHIN_GENES_values.txt
    echo "\${betalactam_methicillin_genes}" > BETA_LACTAM_METHICILLIN_GENES_values.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinderplus: \$(amrfinder --version)
        amrfinderplus-database: \$(echo \$(amrfinder --database amrfinderdb --database_version 2> stdout) | rev | cut -f 1 -d ' ' | rev)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "na" > "${prefix}_amrfinder_all.tsv"
    echo "na" > "${prefix}_amrfinder_amr.tsv"
    echo "na" > "${prefix}_amrfinder_stress.tsv"
    echo "na" > "${prefix}_amrfinder_virulence.tsv"
    echo "na" > AMR_CORE_GENES_values.txt
    echo "na" > AMR_PLUS_GENES_values.txt
    echo "na" > STRESS_GENES_values.txt
    echo "na" > VIRULENCE_GENES_values.txt
    echo "na" > AMR_CLASSES_values.txt
    echo "na" > AMR_SUBCLASSES_values.txt
    echo "na" > BETA_LACTAM_GENES_values.txt
    echo "na" > BETA_LACTAM_BETA_LACTAM_GENES_values.txt
    echo "na" > BETA_LACTAM_CARBAPENEM_GENES_values.txt
    echo "na" > BETA_LACTAM_CEPHALOSPORIN_GENES_values.txt
    echo "na" > BETA_LACTAM_CEPHALOTHIN_GENES_values.txt
    echo "na" > BETA_LACTAM_METHICILLIN_GENES_values.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinderplus: \$(amrfinder --version)
        amrfinderplus-database: \$(echo \$(amrfinder --database amrfinderdb --database_version 2> stdout) | rev | cut -f 1 -d ' ' | rev)
    END_VERSIONS
    """
}