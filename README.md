# LCL-long-read
Long read analysis pipeline for the genetic compensation project

## Motivation
Part of the genetic compensation project - create a pipeline for long read alignment, phasing, sorting at RYR1 and MYH7 loci fo allele specific deletion

## Usage
Run on Nimbus1 in `screen` on filtered (PASS) ONT fastqs \
`bash launch_RYR1.sh`

## Installation
Make sure VEP is installed and up to date (currently v 108) \
Conda env `.yml`s for `long_read` and `vep` are included in this repo

## Method
1. Map reads to reference using minimap
2. Convert output SAM to BAM, sort, index
3. Call SNPs and small indels with NanoCaller and phase
4. Merge SNPs and indels using BCFtools
5. Annotate variants using VEP, to add allele frequencies, in silico predicitons, transcript information
6. Split VEP output into something more user friendly
