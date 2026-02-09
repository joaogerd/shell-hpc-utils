#!/usr/bin/env bash
#BOP
# !FUNCTION: __need_val
# !INTERFACE: __need_val <opt> <val>
# !DESCRIPTION:
#   Guard helper to enforce that an option which requires an argument actually
#   receives one. It fails when the value is missing or when the next token
#   "looks like" another option (i.e., starts with a dash '-').
#
# !USAGE:
#   # Inside an option parser:
#   while [[ $# -gt 0 ]]; do
#     case "$1" in
#       -A|--analysis)
#         __need_val "$1" "$2" || exit $?
#         analysis="$2"; shift 2;;
#       -n|--ntasks)
#         __need_val "$1" "$2" || exit $?
#         ntasks="$2"; shift 2;;
#       --) shift; break;;
#       *)  break;;
#     esac
#   done
#
# !RETURNS:
#   0  if a non-empty value is provided and does not start with '-'
#   EX_USAGE (default 1) otherwise
#
# !EXIT CODES:
#   EX_USAGE  Usage error; missing or invalid value for the given option.
#
# !EXAMPLES:
#   __need_val "--levels" "$2" || exit $?
#   # If $2 is empty or "-x", logs an error and returns EX_USAGE.
#
# !DEPENDENCIES:
#   - _log_err: logging helper supporting printf-style formatting.
#   - EX_USAGE: optional environment variable with the numeric code for usage errors.
#
# !NOTES:
#   - This helper only validates presence and a simple shape check (leading '-').
#     If you need type/regex validation (e.g., integers), perform it after this call.
#   - Bash-specific conditionals ([[ ... ]]) are used intentionally.
#EOP
#BOC
__need_val() {  # usage: __need_val "$1" "$2" || return 1
  local opt="$1"
  local val="${2:-}"
  # Fail if value is empty or looks like a new option (starts with '-')
  if [[ -z "$val" || "$val" == -* ]]; then
    _log_err "Option %s requires a value" "$opt"
    return "${EX_USAGE:-1}"
  fi
  return 0
}
#EOC

###############################################################################
#BOP
#
# !FUNCTION: __parse_args__
#
# !INTERFACE:
#   __parse_args__ "$@"
#
# !DESCRIPTION:
#   Parse common CLI options for build/run scripts, including verbosity,
#   safety utilities (yes/restore/fix/dry-run), scheduler queue/job metadata,
#   and HPC resource layout (MPI/OpenMP). Unknown/legacy short flags are
#   rejected with a helpful error.
#
#   Verbosity & utilities:
#     -v, --verbose          → verbose=true     (enable logging)
#     -q, --quiet            → verbose=false    (disable logging)
#     -d, --debug            → debug=true       (enable debug logging)
#     -y, --yes              → auto_yes=true    (auto-confirm prompts)
#     -f, --fix              → do_fix=true      (create dirs/symlinks/copies as needed)
#         --dry-run          → dry_run=true     (skip actual actions)
#         --restore          → do_restore=true  (restore from *.bak when supported)
#
#   Scheduler / queueing:
#     -Q, --queue <name>     → queue="name"     (set queue/partition)
#         --queue=name       → same as above
#         --job-name <name>  → job_name="name"  (scheduler job name)
#         --walltime <HH:MM:SS> → walltime="..." (requested wall clock)
#
#   HPC resources (long-only):
#         --ntasks <N>           → mpi_tasks=N
#         --cpus-per-task <N>    → omp_threads=N
#         --nodes <N>            → nodes=N
#         --cores-per-node <N>   → cores_per_node=N
#         --procs <N>            → total_procs=N
#
#   Behavior:
#     1) Flags are evaluated in order — the *last one wins*.
#     2) If only --procs and --cpus-per-task are given, mpi_tasks is derived as:
#          mpi_tasks = ceil(total_procs / omp_threads)
#     3) Remaining positional arguments are preserved in leftover_args[].
#
#   Legacy flags (explicitly removed; cause an error if used):
#     -D, -dryrun      (use --dry-run)
#     -pq              (use -Q|--queue <name>)
#     -pn              (use --job-name <name>)
#     -pw              (use --walltime <HH:MM:SS>)
#     -np, -d, -N, -c, -P  (use the long forms: --ntasks/--cpus-per-task/--nodes/
#                           --cores-per-node/--procs)
#
# !USAGE:
#   __parse_args__ "$@"
#   # After parsing, use exported variables:
#   $verbose    && _log_info "Queue: %s" "$queue"
#   $debug      && _log_dbg  "MPI=%s OMP=%s Nodes=%s" "$mpi_tasks" "$omp_threads" "$nodes"
#   if $dry_run; then _log_info "DRY-RUN: args → %s" "${leftover_args[*]}"; fi
#
# !RETURNS:
#   0 on success.
#   2 if a removed/legacy flag is detected.
#
# !ENVIRONMENT:
#   Respects existing environment defaults when set before parsing:
#     verbose, debug, auto_yes, dry_run, do_restore, do_fix,
#     queue, job_name, walltime,
#     mpi_tasks, omp_threads (default 1), nodes, cores_per_node, total_procs.
#
# !EXAMPLES:
#   __parse_args__ -v --dry-run -Q PESQ1 --job-name test --walltime 00:20:00 \
#                  --ntasks 64 --cpus-per-task 2 --nodes 4 --cores-per-node 32 -- echo OK
#
#   __parse_args__ --procs 128 --cpus-per-task 4  # → derives mpi_tasks=32
#
# !NOTES:
#   - Uses a local "strict mode" wrapper (_with_strict_mode) only for this function.
#   - Declares leftover_args as a global array (declare -g -a) to avoid -u issues.
#   - Queue options are optional; default scheduler policy applies when unset.
#
#EOP
###############################################################################
#BOC

__parse_args__() {
  _with_strict_mode   # enable strict mode only for this function
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  # --- respect optional write-leftovers toggle (generic) ---
  local write_leftovers="${PARSER_WRITE_LEFTOVERS:-1}"

  # ---- Safe defaults (respect existing env vars) ----
  verbose=${verbose:-false}
  debug=${debug:-false}
  auto_yes=${auto_yes:-false}
  dry_run=${dry_run:-false}
  do_restore=${do_restore:-false}
  do_fix=${do_fix:-false}

  queue=${queue:-}
  job_name=${job_name:-}
  walltime=${walltime:-}

  mpi_tasks=${mpi_tasks:-}
  omp_threads=${omp_threads:-1}
  nodes=${nodes:-}
  cores_per_node=${cores_per_node:-}
  total_procs=${total_procs:-}

  # Only (re)declare/reset leftover_args if we are allowed to write it
  if [[ "$write_leftovers" != 0 ]]; then
    declare -g -a leftover_args 2>/dev/null || true
    leftover_args=()
  fi

  # Parse only new canonical flags; reject legacy ones with a helpful error
  while [[ $# -gt 0 ]]; do
    opt="$1"
    case $opt in
      # ---- Verbosity and behavior ----
      -v|--verbose) verbose=true; shift; continue ;;
      -q|--quiet)   verbose=false; shift; continue ;;
      -d|--debug)   debug=true; verbose=true; shift; continue ;;
      -y|--yes)     auto_yes=true; shift; continue ;;
      -f|--fix)     do_fix=true; shift; continue ;;
      --dry-run)    dry_run=true; verbose=true; shift; continue ;;
      --restore)    do_restore=true; shift; continue ;;

      # ---- Queue/Job/Walltime ----
      -Q|--queue)        queue="${2:?--queue needs a value}"; shift 2; continue ;;
      --queue=*)         queue="${1#*=}"; shift; continue ;;
      --job-name)        job_name="${2:?--job-name needs a value}"; shift 2; continue ;;
      --walltime)        walltime="${2:?--walltime needs a value}"; shift 2; continue ;;

      # ---- HPC resources (long-only) ----
      --ntasks)          mpi_tasks="${2:?--ntasks needs a value}"; shift 2; continue ;;
      --cpus-per-task)   omp_threads="${2:?--cpus-per-task needs a value}"; shift 2; continue ;;
      --nodes)           nodes="${2:?--nodes needs a value}"; shift 2; continue ;;
      --cores-per-node)  cores_per_node="${2:?--cores-per-node needs a value}"; shift 2; continue;;
      --procs)           total_procs="${2:?--procs needs a value}"; shift 2; continue;;
      # ---- legados proibidos ----
      -D|-dryrun) _log_err "Removed flag: %s → use --dry-run" "$1"; return 2 ;;
      -pq)        _log_err "Removed flag: -pq → use -Q|--queue <name>"; return 2 ;;
      -pn)        _log_err "Removed flag: -pn → use --job-name <name>"; return 2 ;;
      -pw)        _log_err "Removed flag: -pw → use --walltime <HH:MM:SS>"; return 2 ;;
      -np|-d|-N|-c|-P)
                   _log_err "Removed short HPC flags (%s). Use long: --ntasks/--cpus-per-task/--nodes/--cores-per-node/--procs" "$1"
                   return 2 ;;
      # ---- End of options / passthrough ----
      --)    (( write_leftovers )) && leftover_args+=("$1"); break ;;
      --?*)  (( write_leftovers )) && leftover_args+=("$1"); shift; continue ;;
      -?*)   (( write_leftovers )) && leftover_args+=("$1"); shift; continue ;;
      *)     (( write_leftovers )) && leftover_args+=("$1"); shift; continue ;;
    esac
  done

  
  # derive layout if only total_procs provided
  if [[ -n "${total_procs}" && -z "${mpi_tasks}" ]]; then
    (( omp_threads <= 0 )) && omp_threads=1
    mpi_tasks=$(( (total_procs + omp_threads - 1) / omp_threads ))
  fi

  export verbose debug auto_yes dry_run do_restore do_fix
  export queue job_name walltime
  export mpi_tasks omp_threads nodes cores_per_node total_procs
  
  _log_debug "Parsed args: verbose=%s debug=%s dry_run=%s ..." "$verbose" "$debug" "$dry_run" 
  _log_debug "job=%s Queue=%s walltime=%s MPI=%s OMP=%s nodes=%s cores/node=%s procs=%s" \
             "${job_name:-}" "${queue:-}" "${walltime:-}" "${mpi_tasks:-}" "${omp_threads:-}" \
             "${nodes:-}" "${cores_per_node:-}" "${total_procs:-}"
  _log_debug 'leftovers=(%s)' "$(printf '%q ' "${leftover_args[@]}")"
}
#EOC

