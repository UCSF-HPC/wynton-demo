#!/bin/env bash
#$ -S /bin/bash     # the shell language when run via the job scheduler [IMPORTANT]
#$ -notify          # tell SGE to shut down job nicely [IMPORTANT]
#$ -cwd             # use current working directory
#$ -j yes           # merge stdout and stderr
#$ -l h_rt=00:05:00 # 5 minutes of runtime
#$ -l scratch=20G   # needs 20 GiB of /scratch space


############################################################################
#' Configures a size-limited TMPDIR per SGE allocations
#'
#' Usage:
#'   eval "$(fuse_tmpdir)"
#'
#' Options:
#'   --debug           Enable debug output
#'   --default=<size>  The default TMPDIR size in bytes, if not request
#'                     via SGE [default: 1G, which is 1 GiB = 1024 MiB]
#'
#' Examples:
#'   eval "$(fuse_tmpdir)"                 ## recommended
#'
#'   eval "$(fuse_tmpdir --default=10G)"
#'   eval "$(fuse_tmpdir --debug)"         ## for debugging purpose
#'
#' Requirements:
#'   SGE jobs must be submitted with the SGE flag '-notify'. If not, an
#'   error is thrown and the current process is exited.
#'
#' Environment variables:
#'   FUSE_TMPDIR_DEFAULT    The default value of '--default=<value>'
#'
#' Details:
#'   The fuse_tmpdir() function queries 'qstat -j "${JOB_ID}"' for the
#'   requested local /scratch amount (per '-l scratch=<size>'). It will
#'   then set up a new, user-specific temporary, size-limited TMPDIR folder
#'   of this size. This prevents a script from overusing the local /scratch
#'   folder. The temporary TMPDIR will be automatically removed when the
#'   script exits (regardless of reason).
#'
#' Warning:
#'   The above command will override any EXIT trap set in the shell.
#'
#' Author: Henrik Bengtsson
#' License: MIT
############################################################################
#shellcheck disable=SC2120
fuse_tmpdir() {
    local debug tmpdir tmpimg
    local cmd
    local sge_scratch
    local exit_trap
    local size_org size
    local -i size_MiB
    local -a bfr

    fatal() {
        >&2 echo "[fuse_tmpdir] ERROR: ${1:?}"
        echo "exit 1"
        exit 1
    }

    ## Default debug mode
    debug=${FUSE_DEBUG:-false}

    ## Default size is 1024 MiB
    size_org=${FUSE_TMPDIR_DEFAULT:-1G}

    # Parse command-line options
    while [[ $# -gt 0 ]]; do
        if [[ ${1} == "--debug" ]]; then
            debug=true

        ## Options (--key=value):
        elif [[ "$1" =~ ^--.*=.*$ ]]; then
            key=${1//--}
            key=${key//=*}
            value=${1//--[[:alpha:]]*=}
	    if [[ "${key}" == "default" ]]; then
		## Assert proper format
		if ! grep -q -E '^[[:digit:]]+(|K|M|G|T)$' <<< "${value}"; then
                     fatal "Unknown size: ${1}"
		fi
		size_org=${value}
            fi
        fi
	shift
    done

    ${debug} && echo >&2 "fuse_tmpdir_setup() ..."

    ## Assert required tools are available
    for cmd in dd fuse2fs fusermount mkfs.ext4; do
        command -v "${cmd}" > /dev/null || fatal "Command '${cmd}' not found"
    done

    ## Set debug mode
    FUSE_DEBUG=${debug}
    export FUSE_DEBUG

    ## Parse default 'size'
    size="${size_org}"
    size="${size/%K/*1024}"
    size="${size/%M/*1024**2}"
    size="${size/%G/*1024**3}"
    size="${size/%T/*1024**4}"
    
    # shellcheck disable=SC2004
    size_MiB=$(eval "echo $(( ${size} / 1024 / 1024 ))")
    ${debug} && echo >&2 "  - size_MiB: ${size_MiB} MiB (expanded from '${size_org}')"

    
    ## An SGE job?
    if [[ -n "$JOB_ID" ]]; then
        ${debug} && echo >&2 "  - Detected SGE job (JOB_ID=${JOB_ID})"

        ## Collect job info
	mapfile -t bfr < <(qstat -xml -j "${JOB_ID}")
        
	## Assert SGE flag '-notify' was specified
        if ! printf "%s\n" "${bfr[@]}" | grep -q -F '<JB_notify>true</JB_notify>'; then
            fatal "SGE flag '-notify' is not specified"
	fi
	
	## Get '-l scratch=<size>' specification
        sge_scratch=$(printf "%s\n" "${bfr[@]}" | awk '/<CE_name>scratch<\/CE_name>/ {found=1} /<\/qstat_l_requests>/ {found=0} found && /<CE_doubleval>/ {print gensub(/.*<CE_doubleval>(.*)<\/CE_doubleval>.*/, "\\1", "g")}')
        if [[ -z "${sge_scratch}" ]]; then
            fatal "SGE option '-l scratch=<size>' was not specified"
        fi
        
        size_MiB=$(printf "%.0f" "${sge_scratch}")
        size_MiB=$((size_MiB / 1024 / 1024))
        ${debug} && >&2 echo "  - Using SGE requested /scratch storage size: ${size_MiB} MiB"
    else
        ${debug} && >&2 echo "  - Using default /scratch storage size: ${size_MiB} MiB"
    fi

    ## Allocate ${size_MiB} bytes of temporary ext4 image
    tmpimg=$(mktemp --suffix=.TMPDIR.ext4 --tmpdir "fuse_tmpdir.XXXXXX")
    ${debug} && >&2 echo "  - Allocating ext4 image file of size ${size_MiB} MiB: ${tmpimg}"
    trap '{ rm "${tmpimg}"; }' EXIT   ## undo, in case ext4 allocation fails
    dd status="none" if=/dev/zero of="${tmpimg}" bs="1M" count="${size_MiB}"
    mkfs.ext4 -q -O "^has_journal" -F "${tmpimg}"
    ${debug} && >&2 ls -l "${tmpimg}"
    ${debug} && >&2 file "${tmpimg}"
    trap '' EXIT                      ## undo above undo

    
    
    ## Mount it using FUSE
    tmpdir=$(mktemp -d --suffix=.TMPDIR --tmpdir "fuse_tmpdir.XXXXXX")
    exit_trap="trap '{ fuse_tmpdir_teardown \"${tmpdir}\" \"${tmpimg}\"; }' EXIT"
    ${debug} && >&2 echo "  - EXIT trap: ${exit_trap}"
    eval "${exit_trap}"   ## undo, in case mount fails

    ## Make tmpdir private
    chmod 0700 "${tmpdir}"

    ##  -o umask="077"
    if ! fuse2fs -o "auto_unmount" -o "fakeroot" -o "rw" -o "uid=$(id -u),gid=$(id -g)" "${tmpimg}" "${tmpdir}"; then
        fatal "'fuse2fs' failed (exit code $?) to mount $((size_MiB))-MiB Ext4 '${tmpimg}' as temporary TMPDIR='${tmpdir}'"
    fi
    ${debug} && >&2 echo "  - mounted temporary TMPDIR folder"
    ## Make temporary TMPDIR private
    chmod 0700 "${tmpdir}"

    ## Assert that TMPDIR exists, has the expected content, and is writable
    if [[ ! -d "${tmpdir}" ]]; then
        fatal "Temporary TMPDIR directory does not exist: ${tmpdir}"
    fi
    if [[ ! -d "${tmpdir}/lost+found/" ]]; then
        fatal "Temporary TMPDIR directory does not contain the expected 'lost+found' folder: ${tmpdir}"
    fi
    ${debug} && >&2 echo "  - TMPDIR has expected content"
    tf=$(mktemp --tmpdir="${tmpdir}")
    if [[ ! -f "${tf}" ]]; then
        rm -f "${tf}"
        fatal "Failed to create a file in the temporary TMPDIR directory: ${tmpdir}"
    fi
    rm -f "${tf}"
    ${debug} && >&2 echo "  - TMPDIR is writable"


    ## Record the ext4 image file inside TMPDIR
    mkdir "${tmpdir}/.fuse-tmpdir" || fatal "Temporary TMPDIR folder is not writable: ${tmpdir}"
    echo "${tmpimg}" > "${tmpdir}/.fuse-tmpdir/tmpimg"
    chmod 400 "${tmpdir}/.fuse-tmpdir/tmpimg"
    chmod 000 "${tmpdir}/.fuse-tmpdir"
    
    TMPDIR=${tmpdir}
    if ${debug}; then
        {
	    echo "  - TMPDIR=${TMPDIR}"
            df -h "${TMPDIR}"
            ls -la "${TMPDIR}"
        } >&2
    fi

    ## Reset exit trap
    trap "" EXIT
    
    ${debug} && echo >&2 "fuse_tmpdir_setup() ... done"

    echo "TMPDIR='${TMPDIR}'; export TMPDIR; FUSE_DEBUG=${FUSE_DEBUG}; ${exit_trap}"
} # fuse_tmpdir()


fuse_tmpdir_teardown() {
    local debug file tmpdir tmpimg

    warning() {
        >&2 echo "[fuse_tmpdir_teardown] WARNING: ${1:?}"
    }

    tmpdir=${1:-${TMPDIR}}
    tmpimg=${2}
    debug=${FUSE_DEBUG:-false}
    
    ${debug} && >&2 echo "fuse_tmpdir_teardown() ..."
    
    if [[ -z "${tmpimg}" ]]; then
        file="${TMPDIR}/.fuse-tmpdir/tmpimg"
        if [[ -f "${file}" ]]; then
            tmpimg=$(cat "${file}")
        else
            warning "Failed to identify the ext4 image file for FUSE TMPDIR folder '${tmpdir}'"
        fi
    fi

    if [[ ! -d "${tmpdir}" ]]; then
        warning "FUSE TMPDIR folder '${tmpdir}' does not exist"
    fi
    
    fusermount -u "${tmpdir}"
    ${debug} && >&2 echo "  Unmounted FUSE TMPDIR folder '${tmpdir}'"
    rm -r -f "${tmpdir}"
    if [[ -d "${tmpdir}" ]]; then
        warning "Failed to remove FUSE TMPDIR folder '${tmpdir}'"
    else
        ${debug} && >&2 echo "  Removed FUSE TMPDIR folder '${tmpdir}'"
    fi

    if [[ -n "${tmpimg}" ]]; then
        if [[ -f "${tmpimg}" ]]; then
            rm "${tmpimg}"
            if [[ -f "${tmpimg}" ]]; then
                warning "Failed to remove ext4 image file '${tmpimg}' for FUSE TMPDIR folder '${tmpdir}"
            else
                ${debug} && >&2 echo "  Removed ext4 image file '${tmpimg}'"
            fi
        else
            warning "Ext4 image file '${tmpimg}' for FUSE TMPDIR folder '${tmpdir}' did not exist"
        fi
    fi
    
    ${debug} && >&2 echo "fuse_tmpdir_teardown() ... done"
} # fuse_tmpdir_teardown()



############################################################################
## Main script
############################################################################
echo "TMPDIR before: ${TMPDIR}"
df -h "${TMPDIR}"

echo "Setting up size-limited TMPDIR"
## Setup size-limited TMPDIR
eval "$(fuse_tmpdir "$@")"

echo "TMPDIR after: ${TMPDIR}"
df -h "${TMPDIR}"
stat "${TMPDIR}"

echo "Using size-limited TMPDIR"
td=$(mktemp -d)
echo "td=${td}"
date > "${td}"/now
cat "${td}"/now

ls -l -a -R "${TMPDIR}"


if [[ -n "$JOB_ID" ]]; then
    echo "--- Job summary -------------------------------------------------"
    qstat -j "$JOB_ID"
fi    
