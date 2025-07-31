process CREATE_COMBINED_FASTA {
    label 'process_single'
    publishDir "${params.outdir}/combined", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    path(fastas)
    path(contigs_file)

    output:
    path "all_concatenated.fa", emit: fasta
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def contigs_filter = contigs_file.name != 'NO_FILE' ? "--contigs-file ${contigs_file}" : ""
    """
    # Create combined FASTA with optional contig filtering
    if [ "${contigs_file.name}" != "NO_FILE" ]; then
        # Filter by accepted contigs
        while IFS= read -r contig; do
            [ -z "\$contig" ] && continue
            for fasta in ${fastas}; do
                awk -v contig="\$contig" '
                BEGIN { in_contig = 0 }
                /^>/ {
                    if (\$0 ~ contig "\$" || \$0 ~ contig "[^a-zA-Z0-9_-]") {
                        in_contig = 1
                        print
                    } else {
                        in_contig = 0
                    }
                    next
                }
                in_contig { print }
                ' "\$fasta"
            done
        done < ${contigs_file} > all_concatenated.fa
    else
        # No filtering, concatenate all
        cat ${fastas} > all_concatenated.fa
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | cut -d' ' -f3 | cut -d',' -f1)
    END_VERSIONS
    """
}