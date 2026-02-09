#!/usr/bin/env bash
#BOP
# !FUNCTION: _bootstrap_env_root
# !INTERFACE: _bootstrap_env_root <ENV_VAR> <ANCHOR_FILE>
# !DESCRIPTION:
#   Ensure that environment variable <ENV_VAR> points to the project root.
#   If <ENV_VAR> is already set (non-empty), the function is idempotent and
#   does nothing. Otherwise, it discovers the root by walking upward from the
#   *caller* script (BASH_SOURCE[1]; falls back to $PWD) using `project_root_of`.
#
# !BEHAVIOR:
#   • Idempotent: if <ENV_VAR> is already set, returns 0 without changes.
#   • Honors PROJECT_MARKERS when already defined; if unset, temporarily uses
#     a default of ".smg_root:<ANCHOR_FILE>" during discovery.
#   • No dry-run simulation (this function configures process environment).
#   • On failure to detect the root, returns non-zero and logs the context.
#
# !USAGE:
#   # Typical auto-init in a helpers file:
#   _bootstrap_env_root SMG_ROOT ".smg_root" || exit $?
#
# !RETURNS:
#   0  success (ENV_VAR exported, or already set)
#   1  failure to detect the root (project_root_of did not find markers)
#
# !NOTES:
#   • Requires Bash 4+.
#   • Default markers are only applied when PROJECT_MARKERS is unset; otherwise
#     the existing PROJECT_MARKERS are used as-is.
#   • Marker validation is delegated to `project_root_of`.
#
# !EXAMPLE:
#   # Use a custom anchor alongside .smg_root:
#   _bootstrap_env_root MY_ROOT ".project_root"
#   printf 'Root = %s\n' "$MY_ROOT"
#EOP
#BOC
_bootstrap_env_root() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  _with_strict_mode   # enable strict mode only for this function

  local env_var="${1:-}"
  local anchor="${2:-}"

  # Argument validation
  if [[ -z "$env_var" || -z "$anchor" ]]; then
    _log_err "_bootstrap_env_root: missing arguments (ENV_VAR='%s' ANCHOR='%s')" \
             "${env_var:-<unset>}" "${anchor:-<unset>}"
    return 1
  fi

  # Already set? Be idempotent.
  # (Use indirect expansion rather than eval.)
  local current="${!env_var-}"
  if [[ -n "$current" ]]; then
    _log_debug "_bootstrap_env_root: %s already set → %s" "$env_var" "$current"
    return 0
  fi

  # Discovery start point (prefer the caller over this file)
  local start="${BASH_SOURCE[1]:-${PWD}}"
  _log_debug "_bootstrap_env_root: start=%s anchor=%s env_var=%s" "$start" "$anchor" "$env_var"

  # Prepare markers (preserve and restore PROJECT_MARKERS around discovery)
  local prev_markers="${PROJECT_MARKERS-}"
  local markers="${PROJECT_MARKERS:-.smg_root:$anchor}"
  PROJECT_MARKERS="$markers"
  _log_debug "_bootstrap_env_root: markers=%s (prev=%s)" "$markers" "${prev_markers:-<unset>}"

  # Root discovery
  local root rc=0
  if ! root="$(project_root_of "$start")"; then
    rc=$?
    # Restore previous PROJECT_MARKERS before returning
    if [[ -n "${prev_markers+x}" ]]; then
      PROJECT_MARKERS="$prev_markers"
    else
      unset PROJECT_MARKERS
    fi
    _log_err "_bootstrap_env_root: project_root_of failed (rc=%d) [start=%s, markers=%s]" \
             "$rc" "$start" "$markers"
    return 1
  fi

  # Restore PROJECT_MARKERS
  if [[ -n "${prev_markers+x}" ]]; then
    PROJECT_MARKERS="$prev_markers"
  else
    unset PROJECT_MARKERS
  fi

  # Export target env var
  printf -v "$env_var" '%s' "$root"
  export "$env_var"
  _log_info "Set %s → %s" "$env_var" "$root"

  return 0
}
#EOC

