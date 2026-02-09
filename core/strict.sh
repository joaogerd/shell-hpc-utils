#!/usr/bin/env bash
#BOP
# !FUNCTION: _with_strict_mode
#
# !DESCRIPTION:
#   Temporarily enable Bash "strict mode" within the current function scope:
#     - `set -e`       : exit on any error
#     - `set -u`       : error on unset variables
#     - `set -o pipefail` : pipeline fails if any command fails
#   The original shell options are snapshotted and automatically restored
#   on function RETURN, ensuring no side effects leak to the caller.
#
# !USAGE:
#   my_func() {
#     _with_strict_mode
#     # ... safe code here ...
#   }
#
# !BEHAVIOR:
#   • Captures the current shell option state via `set +o`.
#   • Enables strict mode.
#   • Installs a RETURN trap that restores the previous options upon exit.
#   • Emits a DEBUG-level log line if debug logging is enabled.
#
# !EXAMPLE:
#   safe_copy() {
#     _with_strict_mode
#     cp -- "$1" "$2"
#   }
#
#   # In this example, any error in cp (missing file, permission issue, etc.)
#   # will stop execution, but once safe_copy returns the original shell
#   # options are restored.
#
# !NOTES:
#   • This pattern allows strict behavior in critical sections without forcing
#     the entire script to run in strict mode.
#   • Safe to reuse in multiple functions; each invocation is scoped.
#
# !DEPENDENCIES:
#   - `_log_debug` for the diagnostic message (optional; silently no-ops if
#     DEBUG logs are disabled).
#
#EOP
#BOC
_with_strict_mode() {
  # Snapshot current options as shell code (e.g., 'set +o errexit; set +o nounset; ...')
  local __o; __o="$(set +o)"

  # Enable strict mode
  set -euo pipefail

  # Restore snapshot when this function returns (expand __o now, not later)
  trap -- "$(printf 'eval %q; trap - RETURN' "$__o")" RETURN
  _log_debug "Strict mode enabled within function scope"
}
#EOC

