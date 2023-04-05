process ANNOTATE_SV {
  tag "$sampleID"

  cpus 1
  memory 8.GB
  time '04:00:00'

  container 'quay.io/jaxcompsci/r-sv_cnv_annotate:4.1.1'

  input:
    // MERGE_SV.out.merged
    tuple val(sampleID), file(merged_sv_bed), val(normal_name), val(tumor_name)
    val(suppl_switch)

  output:
    tuple val(sampleID), file("${sampleID}.manta_gridss_sv_annotated*.bed"), val(normal_name), val(tumor_name), emit: annot_sv_bedpe

  script:

    if (suppl_switch == "main")
    """
    Rscript ${projectDir}/bin/sv/annotate-bedpe-with-databases.r \
        --db_names=gap,DGV,1000G,PON,COSMIC \
        --db_files=${params.gap},${params.dgvBedpe},${params.thousandGVcf},${params.svPon},${params.cosmicBedPe} \
        --slop=500 \
        --db_ignore_strand=COSMIC \
        --bedpe=${merged_sv_bed} \
        --out_file=${sampleID}.manta_gridss_sv_annotated.bed

    """
    else if (suppl_switch == "supplemental")
    """
    Rscript ${projectDir}/bin/sv/annotate-bedpe-with-databases.r \
        --db_names=gap,DGV,1000G,PON,COSMIC \
        --db_files=${params.gap},${params.dgvBedpe},${params.thousandGVcf},${params.svPon},${params.cosmicBedPe} \
        --slop=500 \
        --db_ignore_strand=COSMIC \
        --bedpe=${merged_sv_bed} \
        --out_file=${sampleID}.manta_gridss_sv_annotated_supplemental.bed
    """
}