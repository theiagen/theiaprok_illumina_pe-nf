process SEROTYPEFINDER {
    tag "$meta.id"
    label 'process_low'
    
    container "us-docker.pkg.dev/general-theiagen/staphb/serotypefinder:2.0.1"

    input:
    tuple val(meta), path(assembly)
    
    output:
    tuple val(meta), path ("*_results_tab.tsv"), emit: serotypefinder_report
    tuple val(meta), path ("STF_SEROTYPE"), emit: serotypefinder_serotype
    path "versions.yml", emit: versions
    
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # capture date and version
    date | tee DATE

    # Check if assembly is gzipped and decompress if needed
    if [[ "${assembly}" == *.gz ]]; then
        echo "Input assembly is gzipped. Decompressing..."
        decompressed_assembly=\$(basename "${assembly}" .gz)
        gunzip -c "${assembly}" > "\${decompressed_assembly}"
        assembly="\${decompressed_assembly}"
        echo "Decompressed to \${decompressed_assembly}"
        
        # Run serotypefinder on the decompressed assembly
        serotypefinder.py -i \${assembly}  -x -o .
    else
        echo "Input assembly is not gzipped. Proceeding with original file."
        serotypefinder.py -i ${assembly}  -x -o .
    fi

    mv results_tab.tsv ${prefix}_results_tab.tsv
    
    parse_serotypefinder.py --input ${prefix}_results_tab.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | cut -d' ' -f2)
        serotypefinder: 2.0.2
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "na" > ${prefix}_results_tab.tsv
    echo "na" > STF_SEROTYPE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | cut -d' ' -f2)
        serotypefinder: 2.0.2
    END_VERSIONS
    """
}