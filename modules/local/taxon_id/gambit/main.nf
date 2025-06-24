process GAMBIT {
    tag "$meta.id"
    label "process_medium"

    // Had to update image for this one
    container "us-docker.pkg.dev/general-theiagen/theiagen/gambit:1.1.0"

    input:
    tuple val(meta), path(assembly)
    path gambit_db_genomes
    path gambit_db_signatures

    output:
    tuple val(meta), path("*_gambit.json"), emit: gambit_report
    tuple val(meta), path("*_gambit_closest.csv"), emit: gambit_closest
    tuple val(meta), path("PREDICTED_TAXON"), emit: predicted_taxon
    tuple val(meta), path("PREDICTED_TAXON_RANK"), emit: predicted_taxon_rank
    tuple val(meta), path("NEXT_TAXON"), emit: next_taxon
    tuple val(meta), path("NEXT_TAXON_RANK"), emit: next_taxon_rank
    tuple val(meta), path("MERLIN_TAG"), emit: merlin_tag
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def report_path = "${prefix}_gambit.json"

    """
    set -euo pipefail

    date | tee DATE
    echo "Running Gambit..."

    # set gambit reference dir; will assume that gambit genomes and signatures will be provided by user in tandem or not at all
    # -s evaluates to TRUE if the file exists and has a size greater than zero
    if [[ -s "${gambit_db_genomes}" ]]; then 
      echo "User gabmit db identified; ${gambit_db_genomes} will be utilized for alignment"
      gambit_db_version="\$(basename -- '${gambit_db_genomes}'); \$(basename -- '${gambit_db_signatures}')"
      gambit_db_dir="\${PWD}/gambit_database"
      mkdir \${gambit_db_dir}
      cp ${gambit_db_genomes} \${gambit_db_dir}
      cp ${gambit_db_signatures} \${gambit_db_dir}
    else
     gambit_db_dir="/gambit-db" 
     gambit_db_version="unmodified from gambit container: ~{docker}"
    fi
    
    # Run Gambit first
    gambit -d \${gambit_db_dir} query -f json -o ${report_path} ${assembly} -c ${task.cpus}

    # Parse the Gambit report
    gambit_report_parser.py ${report_path} ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gambit: \$(gambit --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_gambit.json
    touch ${prefix}_gambit_closest.csv
    touch PREDICTED_TAXON
    touch PREDICTED_TAXON_RANK
    touch NEXT_TAXON
    touch NEXT_TAXON_RANK
    touch MERLIN_TAG
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gambit: \$(gambit --version)
    END_VERSIONS
    """

}