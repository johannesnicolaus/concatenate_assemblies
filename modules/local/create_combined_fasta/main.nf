process CREATE_COMBINED_FASTA {
    label 'process_single'
    publishDir "${params.outdir}/combined", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    path(contig_files, stageAs: "by_contig/*")
    path(contigs_file)

    output:
    path "all_concatenated.fa", emit: fasta
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when


    script:
    """
    # Create combined FASTA using contig files
    if [ "${contigs_file.name}" != "NO_FILE" ]; then
        # Filter by allowed contigs in the order they appear in the contigs file
        > all_concatenated.fa
        
        # Ensure the contigs file ends with a newline
        cp ${contigs_file} temp_contigs.txt
        [ -n "\$(tail -c1 temp_contigs.txt)" ] && echo >> temp_contigs.txt
        
        while IFS= read -r contig; do
            # Skip empty lines and clean whitespace
            contig=\$(echo "\$contig" | sed 's/^[[:space:]]*//;s/[[:space:]]*\$//')
            [ -z "\$contig" ] && continue
            
            # Check if the contig file exists and concatenate it
            contig_file="by_contig/\${contig}.fa"
            if [ -f "\$contig_file" ]; then
                echo "Adding contig: \$contig"
                cat "\$contig_file" >> all_concatenated.fa
            else
                echo "Warning: No file found for contig \$contig (\$contig_file)"
            fi
        done < temp_contigs.txt
        
        rm -f temp_contigs.txt
    else
        # No filtering, concatenate all contig files
        cat by_contig/*.fa > all_concatenated.fa
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version 2>&1 | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}