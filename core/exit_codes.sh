#!/usr/bin/env bash
#BOP
# !EXIT CODES & WRAPPERS
# !DESCRIPTION:
#   Standardized exit codes and convenience wrappers for all scripts. They
#   ensure consistent error handling and logging across the project.
#
# !CODES:
#   EX_OK=0         Success — execution completed without errors.
#   EX_USAGE=1      Usage error — invalid command-line arguments or invocation.
#   EX_NOOP=2       No operation — script executed correctly but nothing to do
#                   (e.g., no files staged, empty input).
#   EX_CONFIG=3     Configuration error — required option, environment variable,
#                   or configuration file is missing/invalid.
#   EX_NOINPUT=4    Input missing — required source file or directory not found
#                   or unreadable.
#   EX_CANTCREAT=5  Output error — unable to create/write to destination (e.g.,
#                   permission denied, disk full).
#   EX_FAIL=6       Generic failure — execution error not covered by other codes.
#
# !WRAPPERS:
#   _exit_ok        <format> [args...]     # success, logs OK, exits EX_OK
#   _exit_usage     <format> [args...]     # logs ERROR, exits EX_USAGE
#   _exit_noop      <format> [args...]     # logs INFO, exits EX_NOOP
#   _exit_config    <format> [args...]     # logs ERROR, exits EX_CONFIG
#   _exit_noinput   <format> [args...]     # logs ERROR, exits EX_NOINPUT
#   _exit_cantcreat <format> [args...]     # logs ERROR, exits EX_CANTCREAT
#   _exit_fail      <format> [args...]     # logs ERROR, exits EX_FAIL
#
# !EXAMPLES:
#   [[ $# -eq 0 ]] && _exit_usage "Missing arguments"
#   [[ ! -f "$file" ]] && _exit_noinput "Input file not found: %s" "$file"
#   mkdir -p "$outdir" || _exit_cantcreat "Cannot create output dir: %s" "$outdir"
#
# !NOTES:
#   • Always use symbolic names (EX_*) instead of raw numbers.
#   • Wrappers combine logging + exit in a consistent way.
#   • `_die` remains available for custom codes outside this set.
#EOP
#BOC
readonly EX_OK=0
readonly EX_USAGE=1
readonly EX_NOOP=2
readonly EX_CONFIG=3
readonly EX_NOINPUT=4
readonly EX_CANTCREAT=5
readonly EX_FAIL=6

_exit_ok()        { _log_ok    "$@"; exit "$EX_OK"; }
_exit_usage()     { _die "$EX_USAGE"    "$@"; }
_exit_noop()      { _log_info  "$@"; exit "$EX_NOOP"; }
_exit_config()    { _die "$EX_CONFIG"   "$@"; }
_exit_noinput()   { _die "$EX_NOINPUT"  "$@"; }
_exit_cantcreat() { _die "$EX_CANTCREAT" "$@"; }
_exit_fail()      { _die "$EX_FAIL"     "$@"; }

#EOC

