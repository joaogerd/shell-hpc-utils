#!/usr/bin/env bash
#BOP
# !FUNCTION: _run_project_config
# !INTERFACE: _run_project_config <ENV_VAR> <CONFIG_FILENAME> <TARGET_FN> [ARGS...]
# !DESCRIPTION:
#   Source a project config file located at "<$ENV_VAR>/<CONFIG_FILENAME>" and
#   invoke <TARGET_FN> (a function expected to be defined by that file),
#   forwarding any optional [ARGS...]. Designed to be fail-soft with clear logs:
#   it emits informative DEBUG/ERROR/WARN/OK messages and returns non-zero on
#   recoverable errors so the caller can decide what to do next.
#
# !PARAMETERS:
#   ENV_VAR         Name of an environment variable that holds the project root
#                   directory (e.g., "SMG_ROOT").
#   CONFIG_FILENAME File name relative to the resolved root (e.g., "config_smg.sh").
#   TARGET_FN       Function symbol to call after sourcing the config
#                   (e.g., "_env_export").
#   ARGS...         Optional arguments forwarded to TARGET_FN.
#
# !BEHAVIOR:
#   • Strict scope: enables `set -euo pipefail` only within this function.
#   • Resolves the root from ENV_VAR; if unset/empty, logs an error advising
#     `_bootstrap_env_root` and returns 2.
#   • Builds "<root>/<CONFIG_FILENAME>" and verifies it exists; else returns 3.
#   • Sources the file via `_source_or_explain` (expected to log/handle details).
#   • Verifies <TARGET_FN> is defined after sourcing; else returns 4.
#   • Calls <TARGET_FN> with [ARGS...]; on non-zero exit, logs a warning and
#     returns 5; otherwise logs OK and returns 0.
#   • No dry-run simulation: this function intentionally performs real sourcing
#     and invocation (it configures live shell state).
#
# !RETURNS:
#   0  success (config sourced and TARGET_FN ran successfully)
#   2  ENV_VAR is unset/empty
#   3  config file not found at "<root>/<CONFIG_FILENAME>"
#   4  TARGET_FN is not defined after sourcing the config
#   5  TARGET_FN returned non-zero
#
# !NOTES:
#   • Requires Bash 4+.
#   • `_source_or_explain <path>` must exist; if you don’t have it, replace the
#     call with a plain `source "$path"` (and ensure you log appropriately).
#   • Security: sourcing executes code from the file; only source trusted paths.
#   • Side effects: any exports or definitions in the config persist in the
#     caller environment by design (since sourcing happens in the current shell).
#   • Logging: honors global `verbose`/`debug`; errors always print.
#
# !EXAMPLES:
#   # Minimal usage
#   _run_project_config SMG_ROOT "smg_setup.sh" _env_export
#
#   # With arguments forwarded to the target function
#   _run_project_config SMG_ROOT "smg_setup.sh" compile "--all" "--no-gsi"
#
#   # Handling failures explicitly
#   if ! _run_project_config SMG_ROOT "smg_setup.sh" _env_export; then
#     _log_fail "Project environment could not be initialized"; exit 1
#   fi
#EOP
#BOC
_run_project_config() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  _with_strict_mode   # enable strict mode only for this function

  local env_var="${1:?env var required}"                # e.g., SMG_ROOT
  local cfg_file="${2:?config filename required}"       # e.g., smg_setup.sh
  local target="${3:?target function required}"         # e.g., _env_export
  shift 3 || true
  local -a target_args=( "$@" )

  # Resolve root from env_var
  local root
  eval "root=\"\${$env_var:-}\""
  if [[ -z "$root" ]]; then
    _log_err "%s is not set; call _bootstrap_env_root first" "$env_var"
    return 2
  fi

  local cfg_path="${root%/}/${cfg_file}"
  if [[ ! -f "$cfg_path" ]]; then
    _log_err "Config not found: %s" "$cfg_path"
    return 3
  fi

  _log_debug "run_project_config: cfg=%s target=%s args=[%s]" "$cfg_path" "$target" "${target_args[*]}"

  # Source defensively and then call the target if defined
  _source_or_explain "$cfg_path" || true
  if ! declare -F "$target" >/dev/null 2>&1; then
    _log_err "Target not defined after sourcing config: %s" "$target"
    return 4
  fi

  # Call target
  if ! "$target" "${target_args[@]}"; then
    _log_warn "Target %s returned non-zero" "$target"
    return 5
  fi

  _log_ok "Config %s executed: %s" "$cfg_file" "$target"
  return 0
}
#EOC

###############################################################################
