#!bin/bash

#Get conda envs
source /data/conda/miniconda3/etc/profile.d/conda.sh

#Get input file from command line and make new directories
file=$1
prefix=`basename $1 .fastq.gz`
mkdir $prefix && cd $prefix
echo $prefix

#activate long_read pipeline
conda activate long_read

#Align reads to reference genome
minimap2 -x map-ont -a /data/reference_genome_hg38/Homo_sapiens_assembly38.fasta ../$file > $prefix.sam
echo "Minimap2 finished"

#Convert to BAM, sort, index
samtools view -bS $prefix.sam > $prefix.bam
samtools sort $prefix.bam > ${prefix}_sorted.bam
samtools index ${prefix}_sorted.bam
echo "samtools finished"

#Call SNPs and small indels using NanoCaller, merge with bcftools and get region of interest
NanoCaller --bam ${prefix}_sorted.bam --ref /data/reference_genome_hg38/Homo_sapiens_assembly38.fasta --cpu 10 --chrom chr14 --preset ont --phase
bcftools concat variant_calls.indels.vcf.gz variant_calls.snps.phased.vcf.gz -a -r chr14:22412000-24436000 -Oz -o ${prefix}_merged_snps_indels.vcf.gz
echo "NanoCaller finished"

#Annotate resulting VCF file with VEP
conda activate vep
vep --cache --dir /data/ensembl-vep/ --fork 10 --af_gnomadg --af_gnomade --max_af --plugin CADD,/data/ensembl-vep/Plugins/gnomad.genomes.r3.0.snv.tsv.gz,/data/ensembl-vep/Plugins/gnomad.genomes.r3.0.indel.tsv.gz --hgvs --hgvsg --fasta /data/reference_genome_hg38/Homo_sapiens_assembly38.fasta --species homo_sapiens --input_file ${prefix}_merged_snps_indels.vcf.gz --vcf --output_file ${prefix}_merged_snps_indels_vep.vcf
echo "VEP finished"

#Convert VEP output to something more readable
cat ${prefix}_merged_snps_indels_vep.vcf |\
#Swap columns
awk -F $'\t' ' { print $1, $2, $3, $4, $5, $6, $7, $9, $10, $8 } ' OFS=$'\t' |\
#sed '/^#/!s/\([0-3][\|][0-3]\):/\1\t/g' |\
#In non header (#) lines, split the INFO field on comma (where VEP separates out different transcript information at each variant to a new line, same column). The commas here either contain a num or | before, [^ACGT] selects non ACGT text so positions with multiple ALT alleles are not affected
sed '/^#/!s/\([^ACGT]\),/\1\n\t\t\t\t\t\t\t\t\t/g' |\
#Swap the ALT allele column separator to '-' before we use the ',' as the FS
awk -F '\t' '{ gsub(",","-",$5); print }' OFS='\t' |\
#Swap '|' to ',' in the last column, thereby making them new columns
awk -F '\t' '{ gsub(/\|/,",",$10); print }' OFS=',' \
> ${prefix}_wrong_header.csv
#head -288 final.csv | tail -2
#Get the VEP column header from the VCF header and swap '|' to ','
cat ${prefix}_wrong_header.csv | sed -n -e 's/^.*\(Allele|Con\)/\1/p' | sed 's/[\|]/,/g' > header.txt
header=`cat header.txt`
#echo $header
#Swap 'INFO' in the #CHROM row to be the new VEP header
awk -v header=$header -F '\t' '{ gsub(/INFO/,header,$10); print }' OFS=',' < ${prefix}_wrong_header.csv > ${prefix}_final.csv

cd ..
echo "Finished, output file is ${prefix}/${prefix}_final.csv"
