process CONCATENATE_BY_HAPLOTYPE {
    tag "${meta.sample_id}_${meta.haplotype}"
    label 'process_single'
    publishDir "${params.outdir}/by_haplotype", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(fastas)

    output:
    path "${meta.sample_id}_${meta.haplotype}.fa", emit: fasta
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Concatenate all FASTA files for this haplotype
    cat ${fastas} > ${meta.sample_id}_${meta.haplotype}.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}