#! /usr/bin/sh
#$ -S /usr/bin/sh
#$ -cwd
#$ -j yes
#$ -l h_rt=00:01:00
#$ -l mem_free=10M

## A shell trap is code that is automatically called upon exit
## if the scripts complete succesfully (exit code == 0), or when
## if terminates due to an error (exit code != 0).
## However, it will *not* be called ... [???]
trap '{ echo "EXIT trap called"; [[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID" ; }' EXIT

echo "This job script produces an error below"

echo "PID: $$"

echo "Sleeping for 10 seconds ..."
sleep 10

## Produce an error
{ >&2 echo "ERROR: boom!"; exit 1; }

echo "This line will never be reached"

