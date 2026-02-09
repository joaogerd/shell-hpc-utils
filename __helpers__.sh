#!/usr/bin/env bash
#===============================================================================
# Script: __helpers__.sh
#
# NOTE:
#   This file is a thin wrapper that sources the modularized helpers.
#   The original implementation was split into modules under helpers/.
#===============================================================================

#===============================================================================
# Script: __helpers__.sh
#
# Purpose:
#   Common helper utilities (logging, argument parsing, progress reporting,
#   simple copying/linking with progress, environment assignment/expansion,
#   system detection, and cluster environment export). Designed to be *sourced*
#   by other Bash scripts.
#
# Usage:
#   # Recommended: source this file at the top of your script
#   source "/path/to/__helpers__.sh"
#
#   # Example pattern inside caller scripts:
#   my_command() {
#     _parse_args "$@"
#     $verbose && _log_info "Running my_command with args: %s" "${leftover_args[*]}"
#     # ...
#   }
#
# Notes:
#   - This library is intended to be sourced (not executed). The shebang is
#     present for consistency only; no code runs on direct execution.
#   - Global flag `verbose` defaults to `false`. Set `verbose=true` in the
#     caller to enable logging, or pass `-v/--verbose` to functions that call
#     `_parse_args`.
#   - Functions prefixed with `_` are internal helpers; they can be used by
#     callers, but their interface may evolve conservatively.
#   - Requires Bash 4+ (for namerefs with `local -n`).
#
# Environment:
#   verbose      : boolean string "true"/"false" (default: false)
#   auto_yes     : when true, skip confirmation prompts (default: false)
#   dry_run      : when true, only log actions (default: false)
#   do_restore   : when true, enable restore behavior if supported (default: false)
#   do_fix       : when true, allow creating dirs/symlinks/copies if needed (default: false)
#
# License:
#   LGPL-3.0-or-later (adjust as needed for your project)
#===============================================================================


#-----------------------------------------------------------------------------#
#----------------------- internal helpers (hidden from help) -----------------#
#-----------------------------------------------------------------------------#

# ----------------------------------------------------------------------------
# Wrapper: resolve this directory and source modules
# ----------------------------------------------------------------------------
helpers_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export helpers_dir

source "$helpers_dir/core/logging.sh"
source "$helpers_dir/core/exit_codes.sh"
source "$helpers_dir/core/debug.sh"
source "$helpers_dir/core/strict.sh"
source "$helpers_dir/core/args.sh"
source "$helpers_dir/core/run.sh"
source "$helpers_dir/core/fs.sh"
source "$helpers_dir/core/assign.sh"
source "$helpers_dir/hpc/env_export.sh"
source "$helpers_dir/core/paths.sh"
source "$helpers_dir/project/root.sh"
source "$helpers_dir/project/bootstrap.sh"
source "$helpers_dir/project/run_config.sh"
source "$helpers_dir/hpc/detect.sh"
source "$helpers_dir/hpc/conda.sh"
source "$helpers_dir/utils/fortran.sh"

# -----------------------------------------------------------------------------
# Auto-init: resolve SMG_ROOT when this helpers file is sourced
# Guard: __HELPERS_SH_LOADED avoids re-entrancy
#
# Behavior:
#   • Calls: _bootstrap_env_root SMG_ROOT ".smg_root"
#   • Start path: handled inside _bootstrap_env_root (uses BASH_SOURCE[1] or $PWD)
#   • No-op when SMG_ROOT is already set or the guard is true
#
# Notes:
#   • Do NOT use 'local' at top-level (invalid in Bash outside functions).
#   • Keep the anchor file customizable if needed (via the 'sentinel' var below).
# -----------------------------------------------------------------------------
if [[ "${__HELPERS_SH_LOADED:-false}" != true ]]; then
  # --- Default logging debugging (exported for downstream scripts) ---
  export debug=${debug:-false}

  # Determine the marker (anchor) used to locate the SMG root. If $SMG_ANCHOR is unset,
  # default to ".smg_root". _bootstrap_env_root will use this to bootstrap paths/env.
  anchor="${SMG_ANCHOR:-.smg_root}"
  _log_debug "Auto-init helpers: calling _bootstrap_env_root (anchor=%s)" "$anchor"

  # --- Absolute path to the directory where this helpers script resides ---
  export helpers_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  
  # Try to resolve and export SMG_ROOT using the generic bootstrapper.
  # It is safe to proceed even if it returns non-zero (caller may handle later).
  _bootstrap_env_root SMG_ROOT "$anchor" || \
    _log_warn "Auto-init: SMG_ROOT autodetection failed; current=%s" "${SMG_ROOT:-<unset>}"

  __HELPERS_SH_LOADED=true
  export __HELPERS_SH_LOADED
  _log_debug "Auto-init done; SMG_ROOT=%s" "${SMG_ROOT:-<unset>}"
fi


