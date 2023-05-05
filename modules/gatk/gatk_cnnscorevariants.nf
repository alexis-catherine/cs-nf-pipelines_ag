process GATK_CNNSCORE_VARIANTS {
    tag "$sampleID"

    cpus = 1
    memory = 15.GB
    time = '04:00:00'

    container 'broadinstitute/gatk:4.2.4.1'

    publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID : 'gatk' }", pattern: "*.*vcf", mode:'copy', enabled: params.keep_intermediate

    input:
    tuple val(sampleID), file(vcf), file(vcf_index), path(interval), val(index)

    output:
    tuple val(sampleID), file("*.vcf"), emit: vcf
    tuple val(sampleID), file("*.idx"), emit: idx

    script:
    String my_mem = (task.memory-1.GB).toString()
    my_mem =  my_mem[0..-4]

    """
    gatk --java-options "-Xmx${my_mem}G" CNNScoreVariants  \
    -R ${params.ref_fa} \
    -V ${vcf} \
    -O ${sampleID}_${index}_haplotypecaller.annotated.vcf \
    -L ${interval} 
    """
}
