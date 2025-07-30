process SPATYPER {
    tag "$meta.id"
    label 'process_low'

    container "us-docker.pkg.dev/general-theiagen/biocontainers/spatyper:0.3.3--pyhdfd78af_3"

    input:
    tuple val(meta), path(assembly)
    val do_enrich 

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    tuple val(meta), path("*_values.txt"), emit: spatyper_value_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def enrich = do_enrich ? "--do_enrich" : ""
    """
    # get versioning
    spaTyper --version 2>&1 | sed 's/^.*spaTyper //' | tee VERSION
    
    spaTyper \\
      ${enrich} \\
      --fasta ${assembly} \\
      --output ${prefix}.tsv

    python3 <<EOF
    import csv

    TYPE = []
    REPEATS = []

    with open("./${prefix}.tsv",'r') as tsv_file:
        tsv_reader=csv.reader(tsv_file, delimiter="\t")
        next(tsv_reader, None)  # skip the headers
        for row in tsv_reader:
            TYPE.append(row[-1])
            REPEATS.append(row[-2])

        with open ("TYPE_values.txt", 'wt') as TYPE_fh:
            TYPE_fh.write(','.join(TYPE))

        with open ("REPEATS_values.txt", 'wt') as REPEATS_fh:
            REPEATS_fh.write(','.join(REPEATS))
    EOF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spaTyper: \$(VERSION)
        python3: \$(python3 --version | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    echo "No type found" > TYPE_values.txt
    echo "No repeats found" > REPEATS_values.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spaTyper: \$(VERSION)
        python3: \$(python3 --version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
