process SHIGEIFINDER {
    tag "$meta.id"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/staphb/shigeifinder:1.3.5"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*_shigeifinder.tsv"), emit: shigeifinder_report
    tuple val(meta), path("shigeifinder_serotype.txt"), emit: shigeifinder_serotype
    tuple val(meta), path("shigeifinder_ipaH_presence_absence.txt"), optional: true, emit: shigeifinder_ipaH_presence_absence
    tuple val(meta), path("shigeifinder_num_virulence_plasmid_genes.txt"), optional: true, emit: shigeifinder_num_virulence_plasmid_genes
    tuple val(meta), path("shigeifinder_cluster.txt"), optional: true, emit: shigeifinder_cluster
    tuple val(meta), path("shigeifinder_O_antigen.txt"), optional: true, emit: shigeifinder_O_antigen
    tuple val(meta), path("shigeifinder_H_antigen.txt"), optional: true, emit: shigeifinder_H_antigen
    tuple val(meta), path("shigeifinder_notes.txt"), optional: true, emit: shigeifinder_notes
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # capture date
    date | tee DATE

    # ShigEiFinder checks that all dependencies are installed before running
    echo "checking for shigeifinder dependencies and running ShigEiFinder..."
    # run shigeifinder on assembly; default is 4cpus, so turning down to 2 since it's already very fast
    shigeifinder -i ${assembly} \\
        -t ${task.cpus} \\
        --hits \\
        --output ${prefix}_shigeifinder.tsv

    # parse output TSV
    echo "Parsing ShigEiFinder output TSV..."

    # set helpful output strings if field in TSV is blank by overwriting output TXT files
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 2)" == "" ]; then
       echo "ShigEiFinder ipaH field was empty" > shigeifinder_ipaH_presence_absence.txt
    else
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 2 > shigeifinder_ipaH_presence_absence.txt
    fi
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 3)" == "" ]; then
       echo "ShigEiFinder number of virulence plasmid genes field was empty" > shigeifinder_num_virulence_plasmid_genes.txt
    else
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 3 > shigeifinder_num_virulence_plasmid_genes.txt
    fi
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 4)" == "" ]; then
       echo "ShigEiFinder cluster field was empty" > shigeifinder_cluster.txt
    else
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 4 > shigeifinder_cluster.txt
    fi
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 5)" == "" ]; then
       echo "ShigEiFinder serotype field was empty" > shigeifinder_serotype.txt
    else
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 5 > shigeifinder_serotype.txt
    fi
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 6)" == "" ]; then
       echo "ShigEiFinder O antigen field was empty" > shigeifinder_O_antigen.txt
    else 
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 6 > shigeifinder_O_antigen.txt
    fi
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 7)" == "" ]; then
       echo "ShigEiFinder H antigen field was empty" > shigeifinder_H_antigen.txt
    else
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 7 > shigeifinder_H_antigen.txt
    fi
    if [ "\$(head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 8)" == "" ]; then
       echo "ShigEiFinder notes field was empty" > shigeifinder_notes.txt
    else
       head -n 2 ${prefix}_shigeifinder.tsv | tail -n 1 | cut -f 8 > shigeifinder_notes.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shigeifinder: \$(shigeifinder --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo "Empty" > "${prefix}_shigeifinder.tsv"
    echo "ShigEiFinder ipaH field was empty" > "shigeifinder_ipaH_presence_absence.txt"
    echo "ShigEiFinder number of virulence plasmid genes field was empty" > "shigeifinder_num_virulence_plasmid_genes.txt"
    echo "ShigEiFinder cluster field was empty" > "shigeifinder_cluster.txt"
    echo "ShigEiFinder serotype field was empty" > "shigeifinder_serotype.txt"
    echo "ShigEiFinder O antigen field was empty" > "shigeifinder_O_antigen.txt"
    echo "ShigEiFinder H antigen field was empty" > "shigeifinder_H_antigen.txt"
    echo "ShigEiFinder notes field was empty" > "shigeifinder_notes.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shigeifinder: \$(shigeifinder --version)
    END_VERSIONS
    """
}