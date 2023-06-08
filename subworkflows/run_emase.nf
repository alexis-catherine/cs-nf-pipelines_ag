#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include {BOWTIE} from "${projectDir}/modules/bowtie/bowtie"
include {SAMTOOLS_VIEW} from "${projectDir}/modules/samtools/samtools_view"
include {SAMTOOLS_INDEX} from "${projectDir}/modules/samtools/samtools_index"
include {GBRS_BAM2EMASE} from "${projectDir}/modules/gbrs/gbrs_bam2emase"
include {GBRS_COMPRESS as GBRS_COMPRESS_SE;
         GBRS_COMPRESS as GBRS_COMPRESS_PE} from "${projectDir}/modules/gbrs/gbrs_compress"
include {GBRS_QUANTIFY} from "${projectDir}/modules/gbrs/gbrs_quantify"

workflow RUN_EMASE {

    take:
        read_ch
    
    main:
        // Map each read with BOWTIE
        BOWTIE(read_ch)

        // Apply `-bS` to convert SAM to BAM
        SAMTOOLS_VIEW(BOWTIE.out.sam, '-bS')

        // SAMTOOLS_INDEX(SAMTOOLS_VIEW.out.bam)

            /// ADD INDEX STEP.

        // Convert BAM to EMASE format. 
        GBRS_BAM2EMASE(SAMTOOLS_VIEW.out.bam)

        // Compress EMASE format file. 
        GBRS_COMPRESS_SE(GBRS_BAM2EMASE.out.emase_h5, '')
        // Inputs required: (input_h5 tuple, suffix). Suffix is null except for PE merge. 

        // If PE, join R1 and R2 together with an additonal compress step. 
        if (params.read_type == 'PE'){
            gbrs_compress_pairedReads_input = GBRS_COMPRESS_SE.out.compressed_emase_h5
                                                .groupTuple(size: 2)
                                                .map { sampleID, reads -> tuple( sampleID, reads.sort{it.name} ) }
            // collect GBRS compression. by sample ID then map and sort tuple to [sampleID, [R1, R2]]

            GBRS_COMPRESS_PE(gbrs_compress_pairedReads_input, 'merged')
            // Inputs required: (input_h5 tuple, suffix). Suffix is null except for PE merge, when 'merged' is used.  

            gbrs_quantify_input = GBRS_COMPRESS_PE.out.compressed_emase_h5
            // Setting an input channel for next step, which catches PE or SE files. Here PE files. 
        } else {
            gbrs_quantify_input = GBRS_COMPRESS_SE.out.compressed_emase_h5
            // Setting an input channel for next step, which catches PE or SE files. Here SE files. 
        }

        // Quantify expression
        GBRS_QUANTIFY(gbrs_quantify_input)
        // Note: gbrs quantify is a wrapper around `run-emase` code with `*.alignment_counts` generation added.   

    emit:
        emase_genes_tpm = GBRS_QUANTIFY.out.genes_tpm
        emase_isoforms_tpm = GBRS_QUANTIFY.out.isoforms_tpm
        emase_genes_expected_cout = GBRS_QUANTIFY.out.genes_expected_cout
        emase_isoforms_expected_count = GBRS_QUANTIFY.out.isoforms_expected_count
        emase_genes_alignment_count =  GBRS_QUANTIFY.out.genes_alignment_count
        emase_isoforms_alignment_count = GBRS_QUANTIFY.out.isoforms_alignment_count
        compressed_emase_h5 = gbrs_quantify_input
}

/*
Note 1: `emase run` can be used as an alternative module to provide near identical function as GBRS quantify. 
        Files that are output by run-emase, are identical to `gbrs quantify`. 
        Should the user wish, the include and run statements for `run-emase` are provided as an alternative to `gbrs quantify`.

    include {EMASE_RUN} from "${projectDir}/modules/emase/emase_run"

    EMASE_RUN(gbrs_quantify_input)

Note 2: `emase zero` is another alternative to the above `grbs quanitfy` and `emase run`. However, `emase zero` requires a different input format.
        This could be implimented, but at present code is only provided to pass `*.h5` and `*.compressed.h5` files to the oringal `emase` code base. 
*/
