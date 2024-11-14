#!/bin/env bash
## -------------------------------------------------------------------------
## SGE directives
## -------------------------------------------------------------------------
#$ -S /bin/bash     # the shell language when run via the job scheduler [IMPORTANT]
#$ -notify          # tell SGE to shut down job nicely [IMPORTANT]
#$ -cwd             # use current working directory
#$ -j yes           # merge stdout and stderr
#$ -l h_rt=00:05:00 # 5 minutes of runtime
#$ -l scratch=1G    # request 1 GiB of /scratch space


## -------------------------------------------------------------------------
## Script prologue
## -------------------------------------------------------------------------

## Set up a pre-allocated, size-limited TMPDIR folder that is automatically
## removed when the script exits. The size is set by SGE specification
## '-l scratch=<size>', if specified.
##
## There are two advantages with this approach:
## (1) your TMPDIR is pre-allocated up-front making it unaffected by other
##     jobs filling up local /scratch, and
## (2) your job cannot fill up local /scratch by mistake.
module load CBI wynton-tools
eval "$(wynton utils --apply fuse-tmpdir)"


## -------------------------------------------------------------------------
## Main script
## -------------------------------------------------------------------------
echo "* EXAMPLE: Size-limited TMPDIR folder example ..."

## Using the size-limited TMPDIR folder
echo "TMPDIR: ${TMPDIR}"

echo "Available size and current usage of the TMPDIR folder:"
df -h "${TMPDIR}"

echo "Creating a tempory directory:"
td=$(mktemp -d)

echo "Writing the current date to a 'now' file in the temporary directory:"
date > "${td}"/now
cat "${td}"/now

echo "Creating a 0.5 GiB file in the temporary directory:"
dd status="none" if=/dev/zero of="${td}/large" bs="1M" count="$((1024/2))"
df -h "${TMPDIR}"

echo "Creating an even larger file, resulting in a 'No space left on device' error:"
dd status="none" if=/dev/zero of="${td}/huge" bs="1M" count="$((1 * 1024))"
df -h "${TMPDIR}"

echo "* EXAMPLE: Size-limited TMPDIR folder example ... DONE"


## -------------------------------------------------------------------------
## Script epilogue
## -------------------------------------------------------------------------
if [[ -n "$JOB_ID" ]]; then
    echo
    echo "=============================================================="
    echo " End of Job Summary"
    qstat -j "$JOB_ID"
fi    
