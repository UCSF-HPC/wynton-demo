#! /usr/bin/env Rscript

## Usage:
## ./rscript.R
## Rscript rscript.R
## qsub -cwd -j yes -b yes Rscript rscript.R

args <- commandArgs()
print(args)

print(sessionInfo())
