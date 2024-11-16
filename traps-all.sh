#! /usr/bin/env bash
#$ -S /usr/bin/bash
#$ -notify           ## IMPORTANT: asks SGE to shut down job nicely
#$ -cwd
#$ -j yes
#$ -l h_rt=00:05:00
#$ -l mem_free=10M

echo "Registering traps for all signals ..."
mapfile -t signals < <(trap -l | sed -E 's/[[:digit:]]+[)]//g' | sed -E 's/[[:space:]]+/\n/g' | sed -E '/^$/d')
for signal in "${signals[@]}"; do
    trap "{ >&2 echo '[$(date --rfc-3339=seconds)] Caught signal ${signal}'; }" "${signal}"
    echo " - Registered '${signal}' trap"
done

echo "Sleep - listen - sleep - listen ..."
while true; do sleep 0.5; done

# Exit script
{ >&2 echo "ERROR: boom! Exiting ..."; exit 1; }

echo "This line will never be reached"
