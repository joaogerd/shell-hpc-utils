#!/usr/bin/env bash
#BOP
# !FUNCTION: disable_conda
#
# !INTERFACE:
#   disable_conda [-v|--verbose]
#
# !DESCRIPTION:
#   Deactivate a detected Conda-like environment (if any) to avoid toolchain
#   conflicts (e.g. compiler wrappers, libraries, MPI). The function attempts
#   to call the proper deactivation command and then cleans up environment
#   variables left behind by Conda/Mamba/Micromamba.
#
# !USAGE:
#   disable_conda [-v]
#
# !BEHAVIOR:
#   • If CONDA_PREFIX is set:
#       - Attempt to run `conda deactivate`, falling back to
#         `source deactivate`, `mamba deactivate`, or `micromamba deactivate`.
#       - Ignore errors from missing commands.
#       - Unset common Conda variables:
#           CONDA_PREFIX, CONDA_DEFAULT_ENV, CONDA_PROMPT_MODIFIER.
#   • If CONDA_PREFIX is not set, do nothing except log a message.
#
# !RETURNS:
#   0 always (safe no-op if Conda is not present).
#
# !EXAMPLE:
#   disable_conda -v
#
# !NOTES:
#   • Safe to call multiple times; no effect if already deactivated.
#   • Works even if Conda/Mamba/Micromamba are not installed, as long as
#     logging helpers are available.
#   • Relies on logging helpers: _log_warn, _log_ok, _log_action.
#
#EOP
#BOC
disable_conda() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  # Prevent verbosity changes from leaking outside
  local verbose=${verbose:-false}

  if [[ -z "${CONDA_PREFIX:-}" ]]; then
    _log_ok "No active Conda environment detected."
    _log_debug "disable_conda: done"
    return 0
  fi

  _log_warn "Conda environment detected: %s" "$CONDA_PREFIX"

  if [[ "${dry_run:-false}" == true ]]; then
    _log_action "[DRY-RUN] would deactivate conda/mamba/micromamba and unset env vars"
    _log_debug "disable_conda: done (dry-run)"
    return 0
  fi

  _log_action "Deactivating Conda..."
  # Try deactivation in order of preference, ignore errors
  if command -v conda >/dev/null 2>&1; then
    conda deactivate 2>/dev/null || source deactivate 2>/dev/null || true
  elif command -v mamba >/dev/null 2>&1; then
    mamba deactivate 2>/dev/null || true
  elif command -v micromamba >/dev/null 2>&1; then
    micromamba deactivate 2>/dev/null || true
  else
    _log_warn "Conda command not found, but CONDA_PREFIX was set."
  fi
  
  # Clean up leftover environment variables
  unset CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_PROMPT_MODIFIER
  _log_ok "Conda has been disabled."
  _log_debug "disable_conda: done"
}
#EOC

