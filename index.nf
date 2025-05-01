//process_input_file.nf
nextflow.enable.dsl=2

/*
 * Index the reference genome for use by bwa and samtools.
 */
process BWA_INDEX {

  input:
  path genome

  script:
  """
  bwa index ${genome}
  """
}

genome_reference_channel = Channel.fromPath("data/genome/ecoli_rel606.fasta")

workflow {
  BWA_INDEX( genome_reference_channel )
}
