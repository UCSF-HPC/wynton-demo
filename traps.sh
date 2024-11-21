#! /usr/bin/env bash
#$ -S /usr/bin/bash
#$ -cwd
#$ -j yes
#$ -l h_rt=00:06:00
#$ -l mem_free=10M

############################################################################
# Bash utility functions
############################################################################
function on_signal {
    signal=${1:?}
    printf "[%ss]: Caught signal %s" "${SECONDS}" "${signal}"
    ## Exit on SIGINT, e.g. Ctrl+C
    if [[ "${signal}" == "SIGINT" ]]; then
        echo " => exiting"
        exit 1
    fi
    echo
}

function get_trap {
    signal=${1:?}
    trap -p "${signal}" | sed -E 's/(^trap -- |[[:alnum:]+-]+$)//g'
}

function get_posix_signals {
    trap -l | sed -E 's/[[:digit:]]+[)]//g' | sed -E 's/[[:space:]]+/\n/g' | sed '/^$/d'
}


############################################################################
# Parse CLI arguments
############################################################################
## Comment: We could also simply use signals={0..64},
## but the following approach shows the signal names

## Default maximum run time
runtime=300

## Use all POSIX signals by default
mapfile -t signals < <(get_posix_signals)

while (($# > 0)); do
    ## Options (--key=value):
    if [[ "$1" =~ ^--.*=.*$ ]]; then
        key=${1//--}
        key=${key//=*}
        value=${1//--[[:alpha:]]*=}
        if [[ "${key}" == "include" ]]; then
            if [[ -n ${value} ]]; then
                mapfile -t signals < <(tr ',' $'\n' <<< "${value}")
            else
                signals=()
            fi
        elif [[ "${key}" == "exclude" ]]; then
            if [[ -n ${value} ]]; then
                mapfile -t exclude < <(tr ',' $'\n' <<< "${value}")
            fi
        elif [[ "${key}" == "runtime" ]]; then
            runtime=${value}
        else
            >&2 echo "ERROR: Unknown option: $1"
            exit 1
        fi
    else
        >&2 echo "ERROR: Unknown argument: $1"
        exit 1
    fi
    shift
done

diff=()
for signal in "${signals[@]}"; do
    if [[ ! " ${exclude[*]} " =~ " ${signal} " ]]; then
        diff+=("${signal}")
    fi
done
signals=("${diff[@]}")


############################################################################
# Main
############################################################################
printf "Registering traps for %d signals: " "${#signals[@]}"
for signal in "${signals[@]}"; do
    printf "%s " "${signal}"
    #shellcheck disable=SC2064
    trap "on_signal ${signal}" "${signal}"
done
echo
echo

echo "[${SECONDS}s] Sleep - listen - sleep ..."
echo " - Run time: ${runtime} seconds"
echo " - Process ID: $$"
echo " - To terminate: SIGINT (Ctrl+C)"
echo

while [[ "${SECONDS}" -lt "${runtime}" ]]; do
    sleep 1
    printf "."
#    printf "[%ss] heartbeat\n" "${SECONDS}"
done
echo

echo "[${SECONDS}s] Sleep - listen - sleep ... DONE"
