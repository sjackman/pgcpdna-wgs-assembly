# Analyze plastid DNA (cpDNA) of the white spruce (Picea glauca)
# Copyright 2013 Shaun Jackman

# Data

abyssdir=/projects/ABySS/assemblies/PG/genome/abyss-1.3.4/PG29/20121204/k109
pabiescpdna=http://mirrors.vbi.vt.edu/mirrors/ftp.ncbi.nih.gov/genomes/Chloroplasts/plastids/NC_021456

# Programs

faclean=bioawk -cfastx '{print ">" $$name "\n" $$seq}'

# Phony targets

all: NC_021456.fa.fai NC_021456.gff NC_021456-PG29.bam NC_021456-PG29.sam.cap.bam

install-deps:
	-brew tap homebrew/science
	-brew tap sjackman/tap
	brew install bioawk bwa cap3 samskrit samtools

.PHONY: all
.DELETE_ON_ERROR:
.SECONDARY:

# Rules

PG29-scaffolds.orig.fa:
	ln -s $(abyssdir)/PG29-scaffolds.fa $@
	
PG29-scaffolds.orig.fa.fai:
	ln -s $(abyssdir)/PG29-scaffolds.fa.fai $@

PG29.orig-NC_021456.sam: $(abyssdir)/PG29-scaffolds.fa NC_021456.fa
	bwa mem $^ >$@

NC_021456.fa:
	curl $(pabiescpdna).fna |bioawk -cfastx '{print ">NC_021456.1 " $$name " " $$comment "\n" $$seq}' >$@

NC_021456.gff:
	curl $(pabiescpdna).gff >$@

PG29-scaffolds.fa: PG29.orig-NC_021456.sam.tid
	samtools faidx PG29-scaffolds.orig.fa `<$<` |$(faclean) >$@

PG29-NC_021456.sam: PG29.orig-NC_021456.sam PG29-scaffolds.fa.fai
	grep -v '^@' $< |samtools view -Sht PG29-scaffolds.fa.fai - >$@

NC_021456-PG29.sam: PG29-scaffolds.fa PG29-NC_021456.sam
	samskrit-swap $< <PG29-NC_021456.sam >$@

%.fa.cap.contigs %.fa.cap.singlets: %.fa
	cap3 $< -p 85 -s 400 >$*.fa.cap.log

%.cap.fa: %.fa.cap.singlets %.fa.cap.contigs
	cat $^ >$@

# Pattern rules

NC_021456-%.sam: NC_021456-%.fa NC_021456.fa.bwt
	bwa mem NC_021456.fa $< >$@

%.sam.qid: %.sam
	awk '!/^@/ {print $$1}' $< |sort -nu >$@

%.sam.tid: %.sam
	awk '!/^@/ {print $$3}' $< |sort -nu >$@

%.sam.fa: %.sam
	bioawk -csam '{print ">" $$qname "\n" $$seq}' $< >$@

# Common tools

%.fa.fai: %.fa
	samtools faidx $<

%.fa.bwt: %.fa
	bwa index $<

%.bam: %.sam
	samtools view -Su $< |samtools sort - $*
	samtools index $@
