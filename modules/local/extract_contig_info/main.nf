process EXTRACT_CONTIG_INFO {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(fasta)
    val delimiter

    output:
    tuple val(meta), path(fasta), path("${meta.id}_contigs.txt"), emit: fasta_with_contigs
    path "versions.yml"                                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Extract contig names from renamed FASTA headers
    grep "^>" ${fasta} | sed 's/^>//' | cut -d"${delimiter}" -f3 > ${meta.id}_contigs.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: "5.1.0"
    END_VERSIONS
    """
}