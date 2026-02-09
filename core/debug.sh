#!/usr/bin/env bash
#BOP
# !FUNCTION: _debug_trace_on
#
# !DESCRIPTION:
#   Enable Bash execution tracing (xtrace) when `debug=true`. The trace prefix
#   (PS4) is customized to include timestamp, process ID, function name,
#   source file, and line number, providing detailed context for debugging.
#
# !USAGE:
#   export debug=true
#   _debug_trace_on
#   my_function arg1 arg2
#
# !BEHAVIOR:
#   • Only activates when global variable `debug` is "true".
#   • Sets PS4 so each traced command line has the format:
#       + [<EPOCHREALTIME>] (<PID>) <FUNC>@<SOURCE>:<LINENO>: <command...>
#   • Calls `set -x` to enable tracing.
#
# !EXAMPLE OUTPUT:
#   + [1695842356.123456] (12345) main@script.sh:42: cp input.txt output.txt
#
# !ENVIRONMENT:
#   - debug : "true"/"false". Controls whether trace mode is enabled.
#   - PS4   : Modified locally to format xtrace lines.
#
# !SEE ALSO:
#   _debug_trace_off (to disable tracing after use)
#
#EOP
#BOC
_debug_trace_on() {
  [[ "${debug:-false}" == true ]] || return 0
  # PS4 with timestamp + PID + function + source + line number
  export PS4='+ [${EPOCHREALTIME}] ($$) ${FUNCNAME[0]:-main}@${BASH_SOURCE}:${LINENO}: '
  set -x
}
#EOC

#BOP
# !FUNCTION: _debug_trace_off
#
# !DESCRIPTION:
#   Disable Bash execution tracing (xtrace) when `debug=true`. This is the
#   counterpart of `_debug_trace_on` and should be called after the section
#   you want to trace to restore normal output.
#
# !USAGE:
#   _debug_trace_on
#   # ... commands to trace ...
#   _debug_trace_off
#
# !BEHAVIOR:
#   • Only acts when the global `debug` flag is "true".
#   • Calls `set +x` to turn off tracing.
#
# !ENVIRONMENT:
#   - debug : "true"/"false". Controls whether the function performs any action.
#
# !SEE ALSO:
#   _debug_trace_on
#EOP
#BOC
_debug_trace_off() {
  [[ "${debug:-false}" == true ]] || return 0
  set +x
}
#EOC
#BOP
# !FUNCTION: _dump_cli
# !DESCRIPTION:
#   Print the *effective* CLI arguments received by the entry point or function.
#   Useful for debugging when options are re-parsed or altered.
# !USAGE:
#   _dump_cli "$@"
#EOP
#BOC
_dump_cli() {
  # Always show the argv in debug mode (INFO would be hidden if verbose=false).
  _log_debug 'CLI ARGV:' >&2
  local arg
  for arg in "$@"; do
    _log_debug '  %q' "$arg" >&2
  done
  printf '\n' >&2
}
#EOC


#BOP
# !FUNCTION: _dump_env
# !DESCRIPTION:
#   Print a whitelist of environment variables, avoiding accidental leaks.
#   Accepts prefixes as arguments (e.g., SMG_, GSI_).
# !USAGE:
#   _dump_env SMG_ GSI_ BAM_ CRTM_ READDIAG_
#EOP
_dump_env() {
  local prefix
  for prefix in "$@"; do
    _log_debug 'ENV %s*' "$prefix" >&2
    env | LANG=C LC_ALL=C sort | grep -E "^${prefix}" >&2 || true
  done
}


