process CONCATENATE_BY_CONTIG {
    tag "$contig"
    label 'process_single'
    publishDir "${params.outdir}/by_contig", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(contig), path(fastas)

    output:
    path "${contig}.fa", emit: fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Extract sequences for this contig from all FASTA files
    for fasta in ${fastas}; do
        awk -v contig="${contig}" '
        BEGIN { in_contig = 0 }
        /^>/ {
            # Check if this header contains our contig
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
    done > ${contig}.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | cut -d' ' -f3 | cut -d',' -f1)
    END_VERSIONS
    """
}