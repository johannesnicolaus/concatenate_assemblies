process BGZIP_COMPRESS {
    tag "$fasta"
    label 'process_single'
    publishDir "${params.outdir}/compressed", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/htslib:1.17--h81da01d_2' :
        'biocontainers/htslib:1.17--h81da01d_2' }"

    input:
    path fasta

    output:
    path "*.fa.gz"     , emit: compressed
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    bgzip ${args} -c ${fasta} > ${fasta}.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bgzip: \$(bgzip -h 2>&1 | head -n1 | sed 's/^.*bgzip //; s/ .*\$//')
    END_VERSIONS
    """
}