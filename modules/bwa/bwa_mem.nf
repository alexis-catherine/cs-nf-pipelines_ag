process BWA_MEM {
  tag "$sampleID"

  cpus 8
  memory {60.GB * task.attempt}
  time {30.hour * task.attempt}
  errorStrategy 'retry' 
  maxRetries 1

  container 'quay.io/biocontainers/bwakit:0.7.17.dev1--hdfd78af_1'

  publishDir {
      def type = "${params.workflow}" == 'chipseq' ? ( sampleID =~ /INPUT/ ? 'control_samples/' : 'immuno_precip_samples/') : '' 
      "${params.pubdir}/${ params.organize_by=='sample' ? type+sampleID : 'bwa_mem'}"
  }, pattern: "*.sam", mode: 'copy', enabled: params.keep_intermediate


  input:
  tuple val(sampleID), file(fq_reads), file(read_groups)

  output:
  tuple val(sampleID), file("*.sam"), emit: sam

  script:
  if (params.read_type == "SE"){
    inputfq="${fq_reads[0]}"
    }
  if (params.read_type == "PE"){
    inputfq="${fq_reads[0]} ${fq_reads[1]}"
    }

  score = params.bwa_min_score ? "-T ${params.bwa_min_score}" : ''
  split_hits = params.workflow == "chipseq" ? "-M" : ''
  """
  rg=\$(cat $read_groups)
  bwa mem -R \${rg} \
  -t $task.cpus $split_hits ${params.mismatch_penalty} $score ${params.ref_fa_indices} $inputfq > ${sampleID}.sam
  """
}
