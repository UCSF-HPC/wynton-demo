#!/bin/env bash
#$ -S /bin/bash     # the shell language when run via the job scheduler [IMPORTANT]
#$ -notify          # tell SGE to shut down job nicely [IMPORTANT]
#$ -cwd             # use current working directory
#$ -j yes           # merge stdout and stderr
#$ -l h_rt=00:05:00 # 5 minutes of runtime
#$ -l scratch=20G   # needs 20 GiB of /scratch space


## Import fuse_tmpdir() from wynton-tools
module load CBI wynton-tools
eval "$(wynton utils fuse-tmpdir)"

## Set up size-limited TMPDIR folder (per -l scratch=<size>, if used)
eval "$(fuse_tmpdir)"


## Using the size-limited TMPDIR folder
echo "TMPDIR: ${TMPDIR}"
df -h "${TMPDIR}"

echo "Using size-limited TMPDIR"
td=$(mktemp -d)
echo "td=${td}"
date > "${td}"/now
cat "${td}"/now


if [[ -n "$JOB_ID" ]]; then
    echo "--- Job summary -------------------------------------------------"
    qstat -j "$JOB_ID"
fi    
