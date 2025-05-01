/*
        Variant Calling Nextflow Pipeline
*/

nextflow.enable.dsl=2


params.outdir = "results"
params.genome = "data/genome/ecoli_rel606.fasta"
params.reads = "data/trimmed_reads/*_{1,2}.trim.fastq.gz"




workflow  {
    reference_genome_channel = Channel.fromPath( params.genome, checkIfExists: true)

    reads_channel = Channel.fromFilePairs(params.reads, checkIfExists: true) 

    println """\
        Variant Calling Nextflow Pipeline
        =================================
        genome      : ${params.genome}
        reads       : ${params.reads}
        outdir      : ${params.outdir}
        """
        .stripIndent()


    FASTQC(reads_channel)
    BWA_INDEX(reference_genome_channel)
    BWA_ALIGN(BWA_INDEX.out.bwa_index.combine(reads_channel))
    SAMTOOLS_SORT(BWA_ALIGN.out.aligned_bam)
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.sorted_bam)
    BCFTOOLS_MPILEUP(BWA_INDEX.out.bwa_index.combine(SAMTOOLS_INDEX.out.aligned_sorted_bam))
    BCFTOOLS_CALL(BCFTOOLS_MPILEUP.out.raw_bcf)
    VCFUTILS(BCFTOOLS_CALL.out.variants_vcf)
}


process FASTQC {
    tag{"FASTQC ${reads}"}
    label 'process_low'
    
    publishDir("${params.outdir}/fastqc_trim",mode: "copy")

    input:
    tuple val(sample_id), path(reads)

    output:
    path("*_fastqc*"), emit: fastqc_output

    script:
    """
    fastqc ${reads}
    """
}

process BWA_INDEX {
    tag{"BWA_INDEX ${genome}"}
    label "process_low"

    publishDir("${params.outdir}/bwa_index", mode: "copy")

    input:
    path genome

    output:
    tuple path(genome), path("*"), emit: bwa_index

    script:
    """
    bwa index ${genome}
    """
}

process BWA_ALIGN {
    tag{"BWA_ALIGN ${sample_id}"}
    label 'process_medium'

    publishDir("${params.outdir}/bwa_align", mode: 'copy')

    input:
    tuple path( genome ), path( "*" ), val( sample_id ), path( reads )

    output:
    tuple val( sample_id ), path( "${sample_id}.aligned.bam" ), emit: aligned_bam

    script:
    """
    INDEX=`find -L ./ -name "*.amb" | sed 's/.amb//'`
    bwa mem \$INDEX ${reads} > ${sample_id}.aligned.sam
    samtools view -S -b ${sample_id}.aligned.sam > ${sample_id}.aligned.bam
    """
}

process SAMTOOLS_SORT {
    tag{"SAMTOOLS_SORT ${sample_id}"}
    label 'process_low'

    publishDir("${params.outdir}/bwa_align", mode: "copy")

    input:
    tuple val( sample_id ), path( bam )

    output:
    tuple val( sample_id ), path( "${sample_id}.aligned.sorted.bam" ), emit: sorted_bam

    script:
    """
    samtools sort -o "${sample_id}.aligned.sorted.bam" ${bam}
    """
}


process SAMTOOLS_INDEX {
    tag("SAMTOOLS_INDEX ${sample_id}")
    label 'process_medium'

    publishDir("${params.outdir}/sorted_bam", mode: "copy")

    input:
    tuple val(sample_id), path(sortedbam)

    output:
    tuple val(sample_id), path("${sample_id}.aligned.sorted.bam"),path("*"), emit: aligned_sorted_bam
    script:
    """
    samtools index ${sortedbam}
    """
}


process BCFTOOLS_MPILEUP {
    tag("BCFTOOLS_MPILEUP ${sample_id}")
    label 'process_medium'
    publishDir("${params.outdir}/vcf", mode: "copy")

    input:
    tuple path(genome), path("*"), val(sample_id), path(sorted_bam), path("*")

    output:
    tuple val (sample_id), path("${sample_id}_raw.bcf"), emit: raw_bcf

    script:
    """
    bcftools mpileup -O b -o "${sample_id}_raw.bcf" -f ${genome} ${sorted_bam}
    """
}


process BCFTOOLS_CALL {
    tag("BCFTOOLS_CALL ${sample_id}")
    label 'process_medium'
    publishDir("${params.outdir}/vcf", mode: "copy")

    input:
    tuple val(sample_id), path(raw_bcf)

    output:
    tuple val(sample_id), path("${sample_id}_variants.vcf"), emit: variants_vcf

    script:
    """
    bcftools call --ploidy 1 -m -v -o "${sample_id}_variants.vcf" ${raw_bcf}
    """
}


process VCFUTILS {
    tag("VCFUTILS ${sample_id}")
    label 'process_low'
    publishDir("${params.outdir}/vcf", mode: "copy")

    input:
    tuple val(sample_id), path(variants_vcf)

    output:
    tuple val(sample_id), path("${sample_id}_filtered_variants.vcf"), emit: filtered_variants_vcf

    script:
    """
    vcfutils.pl varFilter ${variants_vcf} > "${sample_id}_filtered_variants.vcf"
    """
}



workflow.onComplete {
   println ( workflow.success ? """
       Pipeline execution summary
       ---------------------------
       Completed at: ${workflow.complete}
       Duration    : ${workflow.duration}
       Success     : ${workflow.success}
       workDir     : ${workflow.workDir}
       exit status : ${workflow.exitStatus}
       """ : """
       Failed: ${workflow.errorReport}
       exit status : ${workflow.exitStatus}
       """
   )
}
