#!/usr/bin/env bash
#BOP
# !SECTION: LOG CORE (centralized logging configuration)
#
# !DESCRIPTION:
#   Defines global, centralized logging configuration knobs used by the helpers.
#   These variables control tagging, timestamps, color behavior, and output
#   file descriptors, while keeping backward compatibility with the existing
#   `verbose`, `debug`, and `dry_run` booleans already used across scripts.
#
# !CONTENT:
#   - LOG_TAG           : Optional static tag prefixed to every log line.
#                         Example: "SMG". Empty by default (no extra tag).
#   - LOG_TIMESTAMPS    : When "1", prepend a timestamp to log lines.
#                         Default "0" (no timestamp).
#   - LOG_TIME_FMT      : Format string for `date(1)` when timestamps are enabled.
#                         Default "%Y-%m-%d %H:%M:%S".
#   - LOG_FD_OUT        : File descriptor used for informational levels
#                         (INFO/OK/ACTION/DEBUG). Default "1" (stdout).
#   - LOG_FD_ERR        : File descriptor used for warning/error levels
#                         (WARN/ERROR/FAIL). Default "2" (stderr).
#   - COLOR             : If "1" and stdout is a TTY, enable ANSI colors.
#                         Set FORCE_COLOR=1 to force colors regardless of TTY.
#
#   Backward-compatibility flags:
#   - verbose           : "true"/"false". When true, INFO/OK/ACTION are printed.
#                         WARN/ERROR/FAIL always print regardless of `verbose`.
#   - debug             : "true"/"false". When true, DEBUG messages print and
#                         optional xtrace helpers may be enabled by the caller.
#   - dry_run           : "true"/"false". When true, execution helpers only log
#                         the intended command (no side effects) and return 0.
#
# !USAGE:
#   # Minimal example (enable timestamps and tag in a calling script):
#   export LOG_TAG="SMG"
#   export LOG_TIMESTAMPS=1
#   export verbose=true
#   export debug=false
#
#   # To force colors even when redirected:
#   export FORCE_COLOR=1
#
#   # To route INFO to a file and keep ERR on stderr:
#   exec 3>>/var/log/mytool-info.log
#   export LOG_FD_OUT=3   # INFO/OK/ACTION/DEBUG → FD 3 (file)
#   export LOG_FD_ERR=2   # WARN/ERROR/FAIL      → FD 2 (stderr)
#
# !NOTES:
#   • These variables are read by the logging helpers during initialization.
#   • Changing them at runtime affects subsequent log lines immediately.
#   • `verbose`, `debug`, and `dry_run` are exported here for consistency across
#     sourced scripts. Call-site argument parsers may override them later.
#
# !LICENSE:
#   LGPL-3.0-or-later
#EOP

LOG_TAG="${LOG_TAG:-}"
LOG_TIMESTAMPS="${LOG_TIMESTAMPS:-0}"
LOG_TIME_FMT="${LOG_TIME_FMT:-%Y-%m-%d %H:%M:%S}"
LOG_FD_OUT="${LOG_FD_OUT:-1}"
LOG_FD_ERR="${LOG_FD_ERR:-2}"

#BOP
# !SECTION: Compatibility Flags
#
# !DESCRIPTION:
#   Preserve and export the commonly used global flags (`verbose`, `debug`,
#   `dry_run`) so they are available across all sourced scripts. These flags
#   control the logging verbosity, debug output, and dry-run behavior.
#
# !CONTENT:
#   - verbose : "true"/"false". When true, INFO/OK/ACTION messages are printed.
#               Default: false.
#   - debug   : "true"/"false". When true, DEBUG messages are printed and
#               optional xtrace helpers may be enabled. Default: false.
#   - dry_run : "true"/"false". When true, execution helpers (_run, copy
#               helpers, etc.) only log the intended actions instead of
#               executing them. Default: false.
#
# !USAGE:
#   # Enable verbose logs in a caller script:
#   export verbose=true
#
#   # Enable debug logs and traces:
#   export debug=true
#
#   # Run in dry-run mode (no side effects, only logs):
#   export dry_run=true
#
# !NOTES:
#   • Defaults are assigned only if variables are unset.
#   • The values are exported so that any sourced script sees a consistent state.
#   • Typically overridden by argument parsing (e.g. `__parse_args__`).
#EOP

export verbose=${verbose:-false}
export debug=${debug:-false}
export dry_run=${dry_run:-false}
export auto_yes=${auto_yes:-false}

#BOP
# !FUNCTION: _log_colors_init
# !DESCRIPTION:
#   Initialize ANSI color tags when stdout is an interactive TTY and COLOR=1.
#   When not a TTY or COLOR != 1, colors are disabled (empty strings).
#   This keeps logs clean when redirected to files or piped.
#
# !NOTES:
#   • Uses stdout (fd 1) as reference for color enablement.
#   • Honors env var COLOR (default: 1). Set COLOR=0 to force no color.
#EOP
#BOC
_log_colors_init() {
  local _COLOR="${COLOR:-1}"
  [[ "${FORCE_COLOR:-0}" == 1 ]] && _COLOR=1
  if [[ -t 1 && "${_COLOR}" = "1" ]]; then
    C_INFO=$'\033[1;34m'   # bold blue
    C_DBG=$'\033[1;35m'    # bold magenta
    C_OK=$'\033[1;32m'     # bold green
    C_WARN=$'\033[1;33m'   # bold yellow
    C_ERR=$'\033[1;31m'    # bold red
    C_ACT=$'\033[1;36m'    # bold cyan
    C_RST=$'\033[0m'
  else
    C_INFO=; C_DBG=; C_OK=; C_WARN=; C_ERR=; C_ACT=; C_RST=
  fi
}
# Initialize at load time (no-op if not TTY)
_log_colors_init
#EOC

#BOP
# !FUNCTION: __log_ts
#
# !DESCRIPTION:
#   Return a timestamp string when `LOG_TIMESTAMPS` is enabled. The format
#   is controlled by `LOG_TIME_FMT`. If `LOG_TIMESTAMPS` is not set to "1",
#   the function returns immediately without printing anything.
#
# !USAGE:
#   ts="$(__log_ts)"   # → "2025-09-27 18:23:45" (if enabled)
#   echo "[$ts] Starting process..."
#
# !ENVIRONMENT:
#   - LOG_TIMESTAMPS : "1" to enable, "0" (default) to disable.
#   - LOG_TIME_FMT   : Format string for date(1). Default "%Y-%m-%d %H:%M:%S".
#
# !RETURNS:
#   Prints the formatted timestamp to stdout when enabled.
#   Returns 0 in all cases.
#
# !NOTES:
#   • Uses the system `date` command, so the format specifiers follow `date(1)`.
#   • Safe to call inline inside log functions.
#   • When disabled, it produces no output, allowing simple concatenation in
#     log lines without extra conditionals.
#EOP
#BOC
__log_ts() {
  [[ "$LOG_TIMESTAMPS" == 1 ]] || return 0
  command date +"$LOG_TIME_FMT"
}
#EOC

#BOP
# !FUNCTION: _log_msg
# !DESCRIPTION:
#   Print a standardized log message with a given level (INFO, OK, WARNING,
#   ACTION, ERROR, FAIL, etc.). Messages are printed only when the global
#   variable `verbose` is set to `true`, unless forced with `-f`.
#   Supports printf-style formatting. Safe with 'set -u'.
#
# !INTERFACE:
#   _log_msg <LEVEL> [-f] <format> [args...]
#
# !EXAMPLES:
#   _log_msg INFO "Starting step %s" "$step"
#   _log_msg WARNING -f "Low disk space: %s" "$mountpoint"
#   _log_msg OK "Built %d target(s) in %0.2f s" "$n" "$elapsed"
#
# !NOTES:
#   • Do not add a trailing newline to <format>; it’s appended automatically.
#   • `verbose` is the Bash boolean string `true` or `false` (default: false).
#   • Output goes to stdout by default; to route to stderr temporarily, wrap:
#       { _log_msg ERR "msg"; } 1>&2
#   • When SUPPRESS_LOGS=true (e.g., help requested as first arg), nothing is printed.
#EOP
#BOC
_log_msg() {

  # Silence everything (including -f) when help was requested
  [[ "${SUPPRESS_LOGS:-false}" == true ]] && return 0

  local level="$1"; shift
  local force=false
  if [[ "${1:-}" == "-f" ]]; then force=true; shift; fi

  # default: verbose=false
  local v="${verbose:-false}"
  # default: debug=false
  local d="${debug:-false}"

  # Gate by log level
  case "${level^^}" in
    DEBUG)   $force || $d || return 0 ;;      # show only if forced or debug=true
    INFO|OK|ACTION)
             $force || $v || return 0 ;;      # show only if forced or verbose=true
    WARNING|WARN|ERROR|ERR|FAIL)
             ;;                               # always show
    *)       $force || $v || return 0 ;;      # unknown levels behave like INFO
  esac

  # map level → color tag + normalized label + File descriptor used (default stdout/stderr)
  local tag color fd ts ptag
  case "${level^^}" in
    DEBUG)    tag="[DEBUG]";   color="$C_DBG"; fd="$LOG_FD_OUT" ;;
    INFO)     tag="[INFO]";    color="$C_INFO"; fd="$LOG_FD_OUT" ;;
    OK)       tag="[OK]";      color="$C_OK";  fd="$LOG_FD_OUT" ;;
    ACTION)   tag="[ACTION]";  color="$C_ACT"; fd="$LOG_FD_OUT" ;;
    WARNING|WARN)
              tag="[WARNING]"; color="$C_WARN"; fd="$LOG_FD_ERR" ;;
    ERROR|ERR)
              tag="[ERROR]";   color="$C_ERR";  fd="$LOG_FD_ERR" ;;
    FAIL)     tag="[FAIL]";    color="$C_ERR";  fd="$LOG_FD_ERR" ;;
    *)        tag="[$level]";  color="";        fd="$LOG_FD_OUT" ;;
  esac

  ts="$(__log_ts)"                   # optional timestamp (empty if disabled)
  ptag="${tag}"                      # base tag (e.g., [INFO], [ERROR])
  [[ -n "$LOG_TAG" ]] && ptag="[$LOG_TAG] ${ptag}"   # prepend global tag if set

  # $1 is the format string; the rest are printf args
  local fmt; fmt="${1:-}"; shift || true

  if [[ -z "$fmt" ]]; then
    printf "%s%s%s\n" "${color}" "${tag}" "${C_RST}"
  else
    # colorize only the tag; message remains plain (better for grepping)
    # use -- to stop printf from interpretarando algo como opção
    printf "%s%s%s %s\n" "${color}" "${tag}" "${C_RST}" "$(printf -- "$fmt" "$@")"
  fi

}
#EOC

#BOP
# !FUNCTION: _log_debug, _log_info, _log_ok, _log_err, _log_warn, _log_action, _log_fail, _die
# !DESCRIPTION:
#   Convenience wrappers around `_log_msg` that set the appropriate level.
#   `_log_err` and `_log_fail` always force output (they behave as if `-f` was passed).
#   Other wrappers accept an optional `-f` to force output.
#
# !INTERFACE:
#   _log_debug   [-f] <format> [args...]
#   _log_info    [-f] <format> [args...]
#   _log_ok      [-f] <format> [args...]
#   _log_warn    [-f] <format> [args...]
#   _log_action  [-f] <format> [args...]
#   _log_err          <format> [args...]   # forced output
#   _log_fail         <format> [args...]   # forced output
#   _die       [code] <format> [args...]
#
# !EXAMPLES:
#   _log_info "Preparing NCEP input copy (layout=%s): %s" "$layout" "$cycle"
#   _log_ok   "Artifacts available at %s" "$outdir"
#   _log_warning -f "Retrying download (%d/%d)..." "$i" "$max"
#   _log_err  "Failed to load cluster paths via vars_export"
#
# !NOTES:
#   • Formatting follows `printf` semantics (placeholders are expanded).
#   • Wrappers append a newline automatically; do not include one in <format>.
#EOP
#BOC

# Wrappers (keep behavior consistent)
_log_debug()   { _log_msg "DEBUG"   "$@"; }
_log_info()    { _log_msg "INFO"    "$@"; }
_log_ok()      { _log_msg "OK"      "$@"; }
_log_warn()    { _log_msg "WARNING" "$@"; }
_log_action()  { _log_msg "ACTION"  "$@"; }

# Errors should always print, regardless of verbose
_log_fail()    { _log_msg "FAIL"  -f "$@"; }
_log_err()     { _log_msg "ERROR" -f "$@"; }
_die()         { local code="${1:-1}"; shift || true; _log_err "$@"; exit "$code"; }
#EOC

