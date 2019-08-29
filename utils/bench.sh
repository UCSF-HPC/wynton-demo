#! /usr/bin/env bash
##############################################################################
## USAGE:
## bench <command>
##
## EXAMPLES:
##
## DETAILS:
## bench() uses 'time' with the following '--format="..."' flags:
##
## %e ru_wallclock  Elapsed real (wall clock) time used by the process, in seconds.
## %S ru_stime      Total number of CPU-seconds used by the system on behalf of the process (in kernel mode), in seconds.
## %U ru_utime      Total number of CPU-seconds that the process used directly (in user mode), in seconds.
## %P cpu_pct       Percentage of the CPU that this job got.  This is just user + system times divided by the total running time.  It also prints a percentage sign.
## 
## %w ru_nvcsw      Number of times that the program was context-switched voluntarily, for instance while waiting for an I/O operation to complete.
## %c ru_nivcsw     Number of times the process was context-switched involuntarily (because the time slice expired).
## 
## %I ru_inblock    Number of file system inputs by the process.
## %O ru_oublock    Number of file system outputs by the process.
## 
## %x exit_status   Exit status of the command.
## %C command       Name and command line arguments of the command being timed.
##
##
##
## %F ru_majflt     Number of major, or I/O-requiring, page faults that occurred while the process was running.  These are faults where the page has actually migrated out of primary memory.
## %R ru_minflt     Number of minor, or recoverable, page faults.  These are pages that are not valid (so they fault) but which have not yet been claimed by other virtual pages.  Thus the data in the page is still valid but the system tables must be updated.
## 
## %r ru_msgrcv     Number of socket messages received by the process.
## %s ru_msgsnd     Number of socket messages sent by the process.
## 
## %k ru_nsignals   Number of signals delivered to the process.
## 
## %M ru_maxrss     Maximum resident set size of the process during its lifetime, in Kilobytes.
## %t ru_avgrss     Average resident set size of the process, in Kilobytes.
## 
## %K               Average total (data+stack+text) memory use of the process, in Kilobytes.
## %W ru_nswap      Number of times the process was swapped out of main memory.
## 
## %X               Average amount of shared text in the process, in Kilobytes.
## %Z               System's page size, in bytes.  This is a per-system constant, but varies between systems.
## %D               Average size of the process's unshared data area, in Kilobytes.
## %p               Average unshared stack size of the process, in Kilobytes.
##############################################################################

## Constants
_BENCH_TIME="$(which time)"
_BENCH_FORMAT="%e\t%S\t%U\t%P\t%w\t%c\t%I\t%O\t%x\t%C"
_BENCH_FORMAT_HEADER="ru_wallclock\tru_stime\tru_utime\tcpu_pct\tru_nvcsw\tru_invcsw\t\tru_inblock\tru_outblock\texit_status\tcommand"

bench_header() {
    printf "$_BENCH_FORMAT_HEADER\n"
}    

bench() {
    "$_BENCH_TIME" --quiet --format "$_BENCH_FORMAT" $*
}    
