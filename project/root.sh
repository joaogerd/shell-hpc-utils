#!/usr/bin/env bash
#BOP
# !FUNCTION: project_root_of
#
# !INTERFACE:
#   project_root_of [<start_path>]
#
# !DESCRIPTION:
#   Find the project root directory by walking up from <start_path> until any
#   known marker is found. If <start_path> is omitted, the function starts from
#   the caller script (BASH_SOURCE[1]) or $PWD as a last resort.
#
# !USAGE:
#   root="$(project_root_of)"                  # auto-detect from caller
#   root="$(project_root_of /some/path)"       # start from explicit path
#
# !BEHAVIOR:
#   • Markers (OR logic) from ${PROJECT_MARKERS}, colon-separated; default:
#       ".git:pyproject.toml:setup.py:config_smg.ksh:etc/mach"
#   • If markers are not found and Git is available, tries:
#       git rev-parse --show-toplevel
#
# !RETURNS:
#   Prints the detected root to stdout and returns 0; returns 1 on failure.
#
# !NOTES:
#   - Pure function (no exports). Uses _with_strict_mode and your loggers.
#   - Portable: avoids GNU readlink -f; relies on cd -P / pwd -P.
#
#EOP
###############################################################################
#BOC
project_root_of() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  _with_strict_mode   # enable strict mode only for this function

  # Determine a sensible starting point:
  # prefer the *caller* file (BASH_SOURCE[1]) over this helpers file (BASH_SOURCE[0])
  local start="${1:-${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$PWD}}}"
  local dir
  if [[ -d "$start" ]]; then
    dir="$(cd -P -- "$start" && pwd -P)" || { _log_err "Invalid start dir: %s" "$start"; return 1; }
  else
    dir="$(cd -P -- "$(dirname -- "$start")" && pwd -P)" || { _log_err "Invalid start path: %s" "$start"; return 1; }
  fi

  # Configure markers (colon-separated)
  local default_markers=".smg_root:config_smg.ksh:.git"
  local markers_str="${PROJECT_MARKERS:-$default_markers}"
  local IFS=':' markers=()
  read -r -a markers <<< "$markers_str"
  _log_debug "Searching project root from: %s (markers: %s)" "$dir" "$markers_str"

  # Walk up looking for any marker
  while : ; do
    for m in "${markers[@]}"; do
      if [[ -e "$dir/$m" ]]; then
        _log_debug "Marker matched: %s at %s" "$m" "$dir"
        _log_info "Project root found at: %s (marker: %s)" "$dir" "$m"
        printf '%s\n' "$dir"
        return 0
      fi
    done
    local parent
    parent="$(dirname -- "$dir")"
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
  done

  # Fallback to Git (optional)
  if command -v git >/dev/null 2>&1; then
    local gtop
    gtop="$(cd -P -- "${start%/*:-$PWD}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || true
    if [[ -n "$gtop" ]]; then
      _log_warn "Markers not found; using Git top-level: %s" "$gtop"
      printf '%s\n' "$gtop"
      return 0
    fi
  fi

  _log_err "Unable to locate project root from: %s" "$start"
  return 1
}
#EOC

