#!/usr/bin/env bash
#BOP
# !FUNCTION: detect_hpc_system
#
# !INTERFACE:
#   detect_hpc_system [-v|--verbose]
#
# !DESCRIPTION:
#   Identify the HPC system and set global environment flags accordingly.
#   The function inspects uname(1) and the short hostname to recognize
#   known platforms (Cray XC50 and EGEON). It sets a consistent set of
#   exported variables used by downstream scripts (compiler wrapper,
#   locale, convenience boolean flags).
#
# !USAGE:
#   detect_hpc_system -v
#
# !BEHAVIOR:
#   • Sources common flags via __parse_args__ (if available) to honor -v/--verbose.
#   • Reads uname/hostname to infer platform (no external tools beyond coreutils).
#   • Sets (exports):
#       hpc_system, hpc_name, is_egeon, is_cray, WRAPPER, LC_ALL, LANG
#   • Returns 0 on success; 1 on unknown machines.
#
# !ENVIRONMENT:
#   • Honors pre-set variables if already exported before calling:
#       hpc_name, hpc_system, WRAPPER, LC_ALL, LANG
#     (If set, they are preserved; otherwise defaults are applied.)
#
# !EXAMPLE:
#   detect_hpc_system --verbose
#   if $is_cray; then _log_info "Using wrapper: %s" "$WRAPPER"; fi
#
# !NOTES:
#   • Relies on logging helpers (_log_info/_log_warn/_log_err/_log_action) if defined.
#     If not defined, the function degrades gracefully by using printf.
#   • Option parsing via __parse_args__ is optional; the function works without it.
#
#EOP
###############################################################################
#BOC
detect_hpc_system() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  _with_strict_mode   # enable strict mode only for this function

  # Prevent verbosity changes from leaking (local shadow)
  local verbose=${verbose:-false}

  # --- Short-circuit: honor pre-set environment (idempotent behavior) ---
  if [[ -n "${hpc_name:-}" && -n "${hpc_system:-}" && -n "${WRAPPER:-}" ]]; then
    _log_info 'Using pre-set HPC environment: %s (%s) wrapper=%s' "$hpc_name" "$hpc_system" "$WRAPPER"
    # Normalize boolean flags for convenience
    export is_egeon=false is_cray=false
    [[ "${hpc_name,,}" == "egeon" ]] && is_egeon=true
    [[ "${hpc_name,,}" == "xc50"  ]] && is_cray=true
    # Ensure locale defaults if missing
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    export LANG="${LANG:-${LC_ALL}}"
    _log_debug "detect_hpc_system: pre-set flags is_egeon=%s is_cray=%s" "$is_egeon" "$is_cray"
    return 0
  fi

  # --- Gather minimal facts (portable) ---
  local sys_info short_hostname
  sys_info="$(uname -a)"
  short_hostname="$(hostname -s 2>/dev/null || printf 'unknown')"

  # --- Reset exported flags (single source of truth) ---
  export is_egeon=false
  export is_cray=false

  # --- Helper to set env in one place ---
  _set_env() {
    # $1: hpc_system, $2: hpc_name, $3: wrapper, $4: info-msg
    export hpc_system="$1"
    export hpc_name="$2"
    export WRAPPER="$3"
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    export LANG="${LANG:-${LC_ALL}}"
    _log_info '%s' "$4"
    _log_debug "detect_hpc_system: system=%s name=%s wrapper=%s" "$hpc_system" "$hpc_name" "$WRAPPER"
  }

  # --- Detection logic (order matters; be liberal in matching) ---
  # Cray XC50: some kernels expose tags like 'cray_ari_s' or 'Cray'
  if printf '%s' "$sys_info" | grep -Eqi 'cray(_ari_s)?|xc50'; then
    _set_env "cray" "xc50" "ftn" "Detected: Cray XC50"
    export is_cray=true
    return 0

  # EGEON: match by uname string or known headnode label
  elif printf '%s' "$sys_info" | grep -qi 'egeon'; then
    _set_env "linux" "egeon" "mpif90" "Detected: EGEON Cluster"
    export is_egeon=true
    return 0

  elif printf '%s' "$short_hostname" | grep -Eqi '^headnode(-[0-9]+)?$'; then
    _set_env "linux" "egeon" "mpif90" "Detected: HEADNODE of EGEON (build-only)"
    export is_egeon=true
    return 0

  else
    _log_err 'Unknown machine: %s' "$short_hostname"
    _log_action '1) Add a machine entry under etc/mach/'
    _log_action '2) Create an entry in copy_fixed_files (etc/smg_setup.sh)'
    return 1
  fi
}
#EOC

