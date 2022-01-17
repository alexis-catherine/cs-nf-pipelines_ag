process READ_GROUPS {
  // ** why is only one read used here?
  tag "sampleID"

  cpus 1
  memory 5.GB
  time '02:00:00'
  clusterOptions '-q batch'

  container 'python_2.7.sif'

  input:
  tuple val(sampleID), file(read)
  file(read_group_pyfile)

  output:
  tuple val(sampleID), file("*.txt"), emit: read_groups

  script:
  log.info "----- Read Group Information Determination Running on: ${sampleID} -----"

  if (${params.organize_by}=='analysis'){
    publishDir "${params.pubdir}/read_groups", pattern: "*read_group.txt", mode: 'copy'
  }
  else if (${params.organize_by}=='sample'){
    publishDir "${params.pubdir}/${sampleID}", pattern: "*read_group.txt", mode: 'copy'
  }
  
  """
  python ${read_group_pyfile} -p -o ${sampleID}_read_group.txt ${read[0]}
  """
  }
