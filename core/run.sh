#!/usr/bin/env bash
#BOP
# !FUNCTION: _run
#
# !DESCRIPTION:
#   Execute a given command with arguments, respecting the global `dry_run`
#   flag. In dry-run mode, the command is not executed; instead, a log line
#   is emitted to indicate what would have been run. In normal mode, the
#   command is executed directly.
#
# !USAGE:
#   dry_run=false
#   _run cp file1 file2          # executes: cp file1 file2
#
#   dry_run=true
#   _run rm -rf /tmp/data        # logs "[DRY-RUN] rm -rf /tmp/data", no action
#
# !BEHAVIOR:
#   • If `dry_run=true`, print a standardized "[DRY-RUN]" log message via
#     `_log_action`, quoting arguments safely, and return success (0).
#   • If `dry_run=false`, log a DEBUG-level message with the command line,
#     then execute the command in place.
#
# !RETURNS:
#   • In dry-run mode: always returns 0.
#   • In normal mode: returns the exit status of the executed command.
#
# !ENVIRONMENT:
#   - dry_run : "true"/"false" (default: false).
#   - _log_action : Logger function used to print simulated command execution.
#   - _log_debug  : Logger function used to print debug-level execution traces.
#
# !NOTES:
#   • Arguments are executed without eval, preserving exact quoting and avoiding
#     shell injection issues.
#   • Designed to be a safe wrapper for critical commands in scripts that need
#     dry-run simulation support.
#EOP
#BOC
# __helpers__.sh
_run() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  # Always receive command as array
  local -a cmd=( "$@" )

  # Pretty-print for dry-run
  if [[ "${dry_run:-false}" == true ]]; then
    _log_info "DRY-RUN: %s" "${cmd[*]}"
    return 0
  fi

  # If first token is a shell function, call it directly
  if declare -F -- "${cmd[0]}" >/dev/null 2>&1; then
    "${cmd[@]}"
    return $?
  fi

  # Otherwise, execute as external command/binary
  "${cmd[@]}"
}


#EOC

