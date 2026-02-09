#!/usr/bin/env bash
#BOP
# !FUNCTION: _resolve_script_dir
# !INTERFACE: _resolve_script_dir <out_var> [bash_source]
# !DESCRIPTION:
#   Resolve the canonical absolute directory of a script, following symlinks.
#   Writes the directory path into <out_var>.
#
# !USAGE:
#   # from inside a script
#   _resolve_script_dir RUN_GSI_DIR "${BASH_SOURCE[0]}"
#   echo "Script dir is $RUN_GSI_DIR"
#
# !ARGUMENTS:
#   <out_var>     Name of variable to receive the resolved directory path.
#   [bash_source] Path to the script (default: "${BASH_SOURCE[0]}").
#
# !NOTES:
#   • Follows symlinks recursively until the real file is found.
#   • Uses pwd -P to resolve .. and symlinked dirs as well.
#   • Safe under set -euo pipefail.
#EOP
#BOC
_resolve_script_dir() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  local __out="${1:?out var required}"
  local __src="${2:-${BASH_SOURCE[0]}}"
  local __orig="$__src"

  # Follow symlinks
  while [[ -L "$__src" ]]; do
    local __link; __link="$(readlink -- "$__src")"
    if [[ "$__link" = /* ]]; then
      __src="$__link"
    else
      __src="$(cd -- "$(dirname -- "$__src")" && cd -- "$(dirname -- "$__link")" && pwd)/$(basename -- "$__link")"
    fi
  done

  # Assign result = directory of resolved file
  local __dir
  __dir="$(cd -- "$(dirname -- "$__src")" && pwd -P)"
  printf -v "$__out" '%s' "$__dir"

  _log_debug "resolve_script_dir: input=%s resolved_dir=%s" "$__orig" "$__dir"
}
#EOC

###############################################################################
