#! /usr/bin/env bash
#$ -S /usr/bin/bash
#$ -cwd
#$ -j yes
#$ -l h_rt=00:06:00
#$ -l mem_free=10M

function on_signal {
    signal=${1:?}
    echo "[${SECONDS}s]: Caught signal ${signal}"
    ## Exit on SIGQUIT, e.g. Ctrl+\
    [[ "${signal}" == "SIGQUIT" ]] && exit 1
}

function get_trap {
    signal=${1:?}
    trap -p "${signal}" | sed -E 's/(^trap -- |[[:alnum:]+-]+$)//g'
}

echo "Registering traps for all signals:"
## Comment: We could also simply use signals={0..64},
## but the following approach shows the signal names
mapfile -t signals < <(trap -l | sed -E 's/[[:digit:]]+[)]//g' | sed -E 's/[[:space:]]+/\n/g' | sed '/^$/d')
for signal in "${signals[@]}"; do
    printf "%s " "${signal}"
    #shellcheck disable=SC2064
    trap "on_signal ${signal}" "${signal}"
done
echo

for signal in "${signals[@]}"; do
    printf "%s: %s\n" "${signal}" "$(get_trap "${signal}")"
done
echo


echo "Sleep - listen - sleep - listen for up to 5 minutes (press Ctrl-\ to terminate)..."
while [[ "${SECONDS}" -lt 300 ]]; do
    echo "[${SECONDS}s]: heartbeat"
    sleep 1
done

echo "Script exited after 5 minutes"
