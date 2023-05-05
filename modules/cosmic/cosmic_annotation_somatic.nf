process COSMIC_ANNOTATION_SOMATIC {
  tag "$sampleID"

  cpus 1
  memory { 40.GB * task.attempt }
  time {20.hour * task.attempt}
  errorStrategy 'retry'
  maxRetries 1

  container 'quay.io/jaxcompsci/py3_perl_pylibs:v2'

  input:
  tuple val(sampleID), file(vcf), val(meta), val(normal_name), val(tumor_name)

  output:
  tuple val(sampleID), file("*_somatic_vep_cosmic_annotated.vcf"), val(meta), val(normal_name), val(tumor_name), emit: vcf

  script:
    """
    python \
    ${projectDir}/bin/pta/add_cancer_gene_census.py \
    ${params.cosmic_cgc} \
    ${vcf} \
    ${sampleID}_somatic_vep_cosmic_annotated.vcf
    """
}

// cosmic for 'pta' pipeline comes from: 
// curl -H "Authorization: Basic ADD AUTHORIZATION" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v97/cancer_gene_census.csv
// the above command provides a URL for curl download
// curl "https://cog.sanger.ac.uk/cosmic/GRCh38/cosmic/v97/cancer_gene_census.csv?AWSAccessKeyId=KRV7P7QR9DL41J9EWGA2&Expires=1672931317&Signature=PK8YAGC%2Bh9veZqc7mIZzywkOSf0%3D" --output cancer_gene_census.csv
