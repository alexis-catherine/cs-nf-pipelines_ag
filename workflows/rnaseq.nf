#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// import modules
include {help} from "${projectDir}/bin/help/rnaseq"
include {param_log} from "${projectDir}/bin/log/rnaseq"
include {getLibraryId} from "${projectDir}/bin/shared/getLibraryId.nf"
include {extract_csv} from "${projectDir}/bin/shared/extract_csv.nf"
include {FILE_DOWNLOAD} from "${projectDir}/subworkflows/aria_download_parse"
include {CONCATENATE_LOCAL_FILES} from "${projectDir}/subworkflows/concatenate_local_files"
include {CONCATENATE_READS_PE} from "${projectDir}/modules/utility_modules/concatenate_reads_PE"
include {CONCATENATE_READS_SE} from "${projectDir}/modules/utility_modules/concatenate_reads_SE"
include {PDX_RNASEQ} from "${projectDir}/subworkflows/pdx_rnaseq"
include {QUALITY_STATISTICS} from "${projectDir}/modules/utility_modules/quality_stats"
include {FASTQ_PAIR} from "${projectDir}/modules/fastq-tools/fastq-pair"
include {FASTQC} from "${projectDir}/modules/fastqc/fastqc"
include {READ_GROUPS} from "${projectDir}/modules/utility_modules/read_groups"
include {RSEM_ALIGNMENT_EXPRESSION} from "${projectDir}/modules/rsem/rsem_alignment_expression"
include {PICARD_ADDORREPLACEREADGROUPS} from "${projectDir}/modules/picard/picard_addorreplacereadgroups"
include {PICARD_REORDERSAM} from "${projectDir}/modules/picard/picard_reordersam"
include {PICARD_SORTSAM} from "${projectDir}/modules/picard/picard_sortsam"
include {PICARD_COLLECTRNASEQMETRICS} from "${projectDir}/modules/picard/picard_collectrnaseqmetrics"
include {RNA_SUMMARY_STATS} from "${projectDir}/modules/utility_modules/aggregate_stats_rna"
include {MULTIQC} from "${projectDir}/modules/multiqc/multiqc"

// help if needed
if (params.help){
    help()
    exit 0
}

// log paramiter info
param_log()

if (params.download_data && !params.csv_input) {
    exit 1, "Data download was specified with `--download_data`. However, no input CSV file was specified with `--csv_input`. This is an invalid parameter combination. `--download_data` requires a CSV manifest. See `--help` for information."
}

if (params.pdx && params.gen_org == 'mouse') {
    exit 1, "PDX analysis was specified with `--pdx`. `--gen_org` was set to: ${params.gen_org}. This is an invalid parameter combination. `--gen_org` must == 'human' for PDX analysis."
}

// prepare reads channel
if (params.csv_input) {

    ch_input_sample = extract_csv(file(params.csv_input, checkIfExists: true))
    
    if (params.read_type == 'PE'){
        ch_input_sample.map{it -> [it[0], [it[2], it[3]]]}.set{read_ch}
        ch_input_sample.map{it -> [it[0], it[1]]}.set{meta_ch}
    } else if (params.read_type == 'SE') {
        ch_input_sample.map{it -> [it[0], it[2]]}.set{read_ch}
        ch_input_sample.map{it -> [it[0], it[1]]}.set{meta_ch}
    }

} else if (params.concat_lanes){
  
  if (params.read_type == 'PE'){
    read_ch = Channel
            .fromFilePairs("${params.sample_folder}/${params.pattern}${params.extension}",checkExists:true, flat:true )
            .map { file, file1, file2 -> tuple(getLibraryId(file), file1, file2) }
            .groupTuple()
  }
  else if (params.read_type == 'SE'){
    read_ch = Channel.fromFilePairs("${params.sample_folder}/*${params.extension}", checkExists:true, size:1 )
                .map { file, file1 -> tuple(getLibraryId(file), file1) }
                .groupTuple()
                .map{t-> [t[0], t[1].flatten()]}
  }
    // if channel is empty give error message and exit
    read_ch.ifEmpty{ exit 1, "ERROR: No Files Found in Path: ${params.sample_folder} Matching Pattern: ${params.pattern}"}

} else {
  
  if (params.read_type == 'PE'){
    read_ch = Channel.fromFilePairs("${params.sample_folder}/${params.pattern}${params.extension}",checkExists:true )
  }
  else if (params.read_type == 'SE'){
    read_ch = Channel.fromFilePairs("${params.sample_folder}/*${params.extension}",checkExists:true, size:1 )
  }
    // if channel is empty give error message and exit
    read_ch.ifEmpty{ exit 1, "ERROR: No Files Found in Path: ${params.sample_folder} Matching Pattern: ${params.pattern}"}

}

// downstream resources (only load once so do it here)
if (params.rsem_aligner == "bowtie2") {
  rsem_ref_files = file("${params.rsem_ref_files}/bowtie2/*")
}
else if (params.rsem_aligner == "star") {
  rsem_ref_files = file("${params.rsem_ref_files}/STAR/${params.rsem_star_prefix}/*")
}
else error "${params.rsem_aligner} is not valid, use 'bowtie2' or 'star'"

// main workflow
workflow RNASEQ {

  // Step 0: Download data and concat Fastq files if needed. 
  if (params.download_data){
      FILE_DOWNLOAD(ch_input_sample)

      FILE_DOWNLOAD.out.read_meta_ch.map{it -> [it[0], it[2]]}.set{read_ch}
      FILE_DOWNLOAD.out.read_meta_ch.map{it -> [it[0], it[1]]}.set{meta_ch}
  }

  // Step 00: Concat local Fastq files from CSV input if required.
  if (!params.download_data && params.csv_input){
      CONCATENATE_LOCAL_FILES(ch_input_sample)
      CONCATENATE_LOCAL_FILES.out.read_meta_ch.map{it -> [it[0], it[2]]}.set{read_ch}
      CONCATENATE_LOCAL_FILES.out.read_meta_ch.map{it -> [it[0], it[1]]}.set{meta_ch}
  }
  
  // Step 00: Concat local Fastq files if required.
  if (params.concat_lanes && !params.csv_input){
      if (params.read_type == 'PE'){
          CONCATENATE_READS_PE(read_ch)
          read_ch = CONCATENATE_READS_PE.out.concat_fastq
      } else if (params.read_type == 'SE'){
          CONCATENATE_READS_SE(read_ch)
          read_ch = CONCATENATE_READS_SE.out.concat_fastq
      }
  }
  
  // ** MAIN workflow starts: 

  // If samples are PDX, run the PDX RNAseq workflow. 
  // Otherwise, run the standard workflow. 

  if (params.pdx){
    
    PDX_RNASEQ(read_ch)

  } else {

    // Step 1: Qual_Stat
    QUALITY_STATISTICS(read_ch)
    
    FASTQ_PAIR(QUALITY_STATISTICS.out.trimmed_fastq)

    FASTQC(QUALITY_STATISTICS.out.trimmed_fastq)

    // Step 2: RSEM
    RSEM_ALIGNMENT_EXPRESSION(FASTQ_PAIR.out.paired_fastq, rsem_ref_files, params.rsem_ref_prefix)

    //Step 3: Get Read Group Information
    READ_GROUPS(QUALITY_STATISTICS.out.trimmed_fastq, "picard")

    // Step 4: Picard Alignment Metrics
    add_replace_groups = READ_GROUPS.out.read_groups.join(RSEM_ALIGNMENT_EXPRESSION.out.bam)
    PICARD_ADDORREPLACEREADGROUPS(add_replace_groups)

    PICARD_REORDERSAM(PICARD_ADDORREPLACEREADGROUPS.out.bam, params.picard_dict)

    // Step 5: Picard Alignment Metrics
    PICARD_SORTSAM(PICARD_REORDERSAM.out.bam)
    
    PICARD_COLLECTRNASEQMETRICS(PICARD_SORTSAM.out.bam, params.ref_flat, params.ribo_intervals)

    // Step 6: Summary Stats

    agg_stats = RSEM_ALIGNMENT_EXPRESSION.out.rsem_stats.join(QUALITY_STATISTICS.out.quality_stats).join(PICARD_COLLECTRNASEQMETRICS.out.picard_metrics)

    RNA_SUMMARY_STATS(agg_stats)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(QUALITY_STATISTICS.out.quality_stats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.quality_stats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(RSEM_ALIGNMENT_EXPRESSION.out.rsem_cnt.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(PICARD_COLLECTRNASEQMETRICS.out.picard_metrics.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
  }
}
