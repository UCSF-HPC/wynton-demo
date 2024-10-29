#!/bin/env bash
#$ -S /bin/bash     # the shell language when run via the job scheduler [IMPORTANT]
#$ -cwd             # use current working directory
#$ -j yes           # merge stdout and stderr
#$ -l h_rt=00:05:00 # 5 minutes of runtime
#$ -l scratch=20G   # needs 20 GiB of /scratch space

############################################################################
## Setup temporary FUSE folder for TMPDIR
############################################################################
## Set to 'true' to enable debug output
FUSE_DEBUG=false

## Scratch storage requested via -l scratch=<size> (in bytes)?
if [[ -n "$JOB_ID" ]]; then
   sge_scratch=$(qstat -xml -j "$JOB_ID" | awk '/<CE_name>scratch<\/CE_name>/ {found=1} /<\/qstat_l_requests>/ {found=0} found && /<CE_doubleval>/ {print gensub(/.*<CE_doubleval>(.*)<\/CE_doubleval>.*/, "\\1", "g")}')
   if [[ -n "${sge_scratch}" ]]; then
     size_MiB=$(printf "%.0f" "${sge_scratch}")
     size_MiB=$((size_MiB / 1024 / 1024))
     $FUSE_DEBUG && >&2 echo "Requested /scratch storage: ${size_MiB} MiB"
   fi
else
   size_MiB=1024 ## Default is 1024 MiB
   $FUSE_DEBUG && >&2 echo "Default /scratch storage: ${size_MiB} MiB"
fi

## Allocate ${size_MiB} bytes of temporary EXT4 image
tmpimg=$(mktemp --suffix=.tmp.img)
$FUSE_DEBUG && >&2 echo "tmpimg=${tmpimg}"
dd status="none" if=/dev/zero of="${tmpimg}" bs="1M" count="${size_MiB}"
mkfs.ext4 -q -O ^has_journal -F "${tmpimg}"
$FUSE_DEBUG && >&2 ls -l "${tmpimg}"
$FUSE_DEBUG && >&2 file "${tmpimg}"

## Mount it using FUSE
tmpdir=$(mktemp -d --suffix=.tmp)
fuse2fs -o "fakeroot" -o "rw" -o "uid=$(id -u),gid=$(id -g)" "${tmpimg}" "${tmpdir}"

## Use it as TMPDIR
TMPDIR=${tmpdir}
export TMPDIR

if $FUSE_DEBUG; then
    {
	echo "Mounted FUSE folder"
	echo "TMPDIR=${TMPDIR}"
        df -h "${TMPDIR}"
        ls -la "$TMPDIR" || echo "ls -la $TMPDIR failed"
    } >&2
fi


############################################################################
## Main script
############################################################################

df -h "${TMPDIR}"
td=$(mktemp -d)
echo "td=${td}"
date > "${td}"/now
cat "${td}"/now


############################################################################
## Teardown temporary FUSE tmpdir
############################################################################
## Unmount and cleanup
fusermount -u "${tmpdir}"
rmdir "${tmpdir}"
rm "${tmpimg}"


echo "--- Job summary -------------------------------------------------"
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"
