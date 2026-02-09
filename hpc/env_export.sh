#!/usr/bin/env bash
#BOP
# !FUNCTION: _env_export
# !INTERFACE: _env_export
# !DESCRIPTION:
#   Load and export cluster-specific environment variables from a config file
#   in `etc/mach/${hpc_name}_paths.conf`. Each line has the format:
#     KEY   VALUE
#   Blank lines and lines starting with '#' are ignored. Leading/trailing
#   whitespace is trimmed. Uses _assign to perform variable expansion and export.
#
# !USAGE:
#   _env_export
#
# !BEHAVIOR:
#   • Builds config file path: $(dirname ${BASH_SOURCE})/mach/${hpc_name}_paths.conf
#   • Aborts if the file is missing
#   • Reads each non-empty, non-comment line
#   • Splits into KEY and VALUE
#   • Calls _assign KEY VALUE (which expands ${VAR} references)
#   • Exports all resulting variables
#
# !EXAMPLE:
#   # inside mach/egeon_paths.conf
#   HOME        /home/${USER}
#   subt_smg    ${SUBMIT_HOME}/${nome_smg}
#
#   # usage
#   _env_export   # sets HOME and subt_smg expanded
#
# !NOTES:
#   • Depends on: _assign
#   • Requires: hpc_name set to match a config file
#EOP
#BOC
_env_export() {
  _with_strict_mode   # enable strict mode only for this function
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  # Avoid re-running if already done
  if [[ "${ENV_EXPORTED:-false}" == "true" ]]; then
    _log_debug "_env_export: already done; skipping"
    return 0
  fi

  # Ensure hpc_name is defined before using it
  if [[ -z "${hpc_name:-}" ]]; then
    _log_warn "hpc_name was not set before loading environment paths!"
    # Try to detect HPC system automatically
    if ! detect_hpc_system; then
      _log_err "detect_hpc_system failed. Aborting."
      return 1
    fi
    _log_info -f "hpc_name set to: %s" "$hpc_name"
  fi

  local confdir="${helpers_dir}/mach"
  local filepaths="${confdir}/${hpc_name}_paths.conf"
  _log_debug "_env_export: config=%s" "$filepaths"

  # Read config line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # trim leading spaces
    line="${line#"${line%%[![:space:]]*}"}"
    # skip empty or comment-only lines
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    # remove inline comments while preserving '#' inside quotes
    line="$(_strip_inline_comment "$line")"
    [[ -z "$line" ]] && continue

    # split into key and value (trim leading spaces from value)
    local key value
    key="${line%%[[:space:]]*}"
    value="${line#"$key"}"
    value="${value#"${value%%[![:space:]]*}"}"

    [[ -z "$key" || -z "$value" ]] && continue
    _assign "$key" "$value"
  done < "$filepaths"
  
  # Mark as already exported
  export ENV_EXPORTED=true
  _log_debug "_env_export: completed (ENV_EXPORTED=true)"

}
#EOC

