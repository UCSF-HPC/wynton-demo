#!/bin/env bash
#$ -S /bin/bash     # the shell language when run via the job scheduler [IMPORTANT]
#$ -notify          # tell SGE to shut down job nicely [IMPORTANT]
#$ -cwd             # use current working directory
#$ -j yes           # merge stdout and stderr
#$ -l h_rt=00:05:00 # 5 minutes of runtime
#$ -l scratch=3G     # needs 3 GiB of /scratch space


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


echo "Creating a 1 GiB temporary file"
dd status="none" if=/dev/zero of="${td}/large" bs="1M" count="$((1 * 1024))"
df -h "${TMPDIR}"

echo "Filling up TMPDIR, resulting in a 'No space left on device' error"
dd status="none" if=/dev/zero of="${td}/huge" bs="1M" count="$((3 * 1024))"
df -h "${TMPDIR}"


if [[ -n "$JOB_ID" ]]; then
    echo "--- Job summary -------------------------------------------------"
    qstat -j "$JOB_ID"
fi    
