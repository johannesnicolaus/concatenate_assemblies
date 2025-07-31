/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_concatenate_assemblies_pipeline'

// Import your local modules
include { RENAME_FASTA_HEADERS   } from '../modules/local/rename_fasta_headers/main'
include { EXTRACT_CONTIG_INFO    } from '../modules/local/extract_contig_info/main'
include { CONCATENATE_BY_CONTIG  } from '../modules/local/concatenate_by_contig/main'
include { CONCATENATE_BY_HAPLOTYPE } from '../modules/local/concatenate_by_haplotype/main'
include { CREATE_COMBINED_FASTA  } from '../modules/local/create_combined_fasta/main'
include { BGZIP_COMPRESS         } from '../modules/local/bgzip_compress/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CONCATENATE_ASSEMBLIES {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()

    //
    // Step 1: Rename FASTA headers
    //
    RENAME_FASTA_HEADERS (
        ch_samplesheet,
        params.delimiter
    )
    ch_versions = ch_versions.mix(RENAME_FASTA_HEADERS.out.versions)

    //
    // Step 2: Extract contig information
    //
    EXTRACT_CONTIG_INFO (
        RENAME_FASTA_HEADERS.out.fasta,
        params.delimiter
    )
    ch_versions = ch_versions.mix(EXTRACT_CONTIG_INFO.out.versions)

    //
    // Step 3: Group by contig for concatenation
    //
    EXTRACT_CONTIG_INFO.out.fasta_with_contigs
        .map { meta, fasta, contigs_file ->
            // Read contig names and create entries for grouping
            def contig_list = file(contigs_file).readLines()
            return contig_list.collect { contig ->
                [contig.trim(), meta, fasta]
            }
        }
        .flatten()
        .collate(3)
        .groupTuple(by: 0)
        .map { contig, metas, fastas ->
            [contig, fastas]
        }
        .set { ch_grouped_by_contig }

    CONCATENATE_BY_CONTIG (
        ch_grouped_by_contig
    )
    ch_versions = ch_versions.mix(CONCATENATE_BY_CONTIG.out.versions.first())

    //
    // Step 4: Group by haplotype for concatenation
    //
    RENAME_FASTA_HEADERS.out.fasta
        .map { meta, fasta ->
            def haplotype_key = [sample_id: meta.sample_id, haplotype: meta.haplotype]
            [haplotype_key, fasta]
        }
        .groupTuple()
        .set { ch_grouped_by_haplotype }

    CONCATENATE_BY_HAPLOTYPE (
        ch_grouped_by_haplotype
    )
    ch_versions = ch_versions.mix(CONCATENATE_BY_HAPLOTYPE.out.versions.first())

    //
    // Step 5: Create combined FASTA file using contig files
    //
    ch_contigs_filter = params.contigs_file ? 
        Channel.fromPath(params.contigs_file) : 
        Channel.fromPath("$projectDir/assets/NO_FILE").first()

    // Collect all contig files from CONCATENATE_BY_CONTIG
    ch_all_contig_files = CONCATENATE_BY_CONTIG.out.fasta.collect()

    CREATE_COMBINED_FASTA (
        ch_all_contig_files,
        ch_contigs_filter
    )
    ch_versions = ch_versions.mix(CREATE_COMBINED_FASTA.out.versions)

    //
    // Step 6: Compress all output files
    //
    ch_files_to_compress = Channel.empty()
        .mix(CONCATENATE_BY_CONTIG.out.fasta)
        .mix(CONCATENATE_BY_HAPLOTYPE.out.fasta)
        .mix(CREATE_COMBINED_FASTA.out.fasta)

    BGZIP_COMPRESS (
        ch_files_to_compress
    )
    ch_versions = ch_versions.mix(BGZIP_COMPRESS.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'concatenate_assemblies_software_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    emit:
    versions = ch_versions // channel: [ path(versions.yml) ]
}