#!/usr/bin/env bash
#BOP
# !FUNCTION: _list_files_array
# !INTERFACE: _list_files_array VAR_NAME SRC_DIR [find_args...]
# !DESCRIPTION:
#   Populate the array named VAR_NAME with the basenames of files found in
#   SRC_DIR (optionally filtered with extra find(1) arguments).
#
# !USAGE:
#   _list_files_array filesArray /path/to/src -name '*.txt'
#
# !BEHAVIOR:
#   • Validates inputs and clears the target array
#   • Runs a pruned, single-level search: find -L SRC_DIR -maxdepth 1 -type f ...
#   • Stores only basenames into VAR_NAME
#   • Emits [DEBUG]/[INFO] logs if $verbose=true
#
# !NOTES:
#   • Requires Bash 4+ (nameref)
#   • Safe if no matches: returns 0 with an empty array
#EOP
#BOC
_list_files_array() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  # optional strict mode if your helper exists
  if declare -F with_strict_mode >/dev/null 2>&1; then with_strict_mode; fi

  local __outvar="${1:?VAR_NAME required}"
  local src_dir="${2:?SRC_DIR required}"
  shift 2 || true

  # nameref to external array
  local -n __arr_ref="$__outvar" 2>/dev/null || {
    _log_err "Target array '%s' is not a valid name" "$__outvar"
    return 2
  }
  __arr_ref=()
  _log_debug "list_files_array: dir=%s filters=%q" "$src_dir" "$*"

  if [[ ! -d "$src_dir" ]]; then
    _log_warn "Source directory not found: %s" "$src_dir"
    return 0
  fi


  # Collect matches (null-delimited)
  local -a __found=()
  if ! mapfile -d '' -t __found < <(find -L "$src_dir" -maxdepth 1 -type f "$@" -print0 2>/dev/null); then
    _log_warn "find failed in %s with args: %q" "$src_dir" "$*"
    return 0
  fi
  
  # Fill array with basenames
  local p
  for p in "${__found[@]}"; do
    __arr_ref+=( "$(basename -- "$p")" )
  done

  _log_debug "list_files_array: found=%s" "${#__arr_ref[@]}"
  _log_info "Found %d file(s) in %s" "${#__arr_ref[@]}" "$src_dir"
  return 0
}
#EOC

#BOP
# !FUNCTION: _progress_bar
# !INTERFACE: _progress_bar <current> <total> <message>
# !DESCRIPTION:
#   Render a simple textual progress bar (width=40) with percentage and counters.
#
# !USAGE:
#   _progress_bar 3 10 "Copying files"
#
# !BEHAVIOR:
#   • Prints a single updating line with carriage return
#   • Shows percent complete and current/total count
#
# !EXAMPLE:
#   for i in {1..10}; do
#     _progress_bar "$i" 10 "Processing"
#     sleep 0.2
#   done
#EOP
#BOC
_progress_bar() {
  local current=${1:-0} total=${2:-0} msg="${3:-Processing}"
  local width=40
  (( total <= 0 )) && { printf "\r%s[INFO]%s %s [no files]\n" "$C_INFO" "$C_RST" "$msg"; return; }
  (( current < 0 )) && current=0
  (( current > total )) && current=$total

  local progress=$(( current * width / total ))
  local percent=$(( 100 * current / total ))

  local bar=""
  for ((i=0; i<width; i++)); do
    if (( i < progress )); then bar+="█"; else bar+="░"; fi
  done
  printf "\r%s[ACTION]%s %s [%s] %3d%% (%d/%d) " \
         "$C_ACT" "$C_RST" "$msg" "$bar" "$percent" "$current" "$total"
}
#EOC

#BOP
# !FUNCTION: _copy_one_safe
# !INTERFACE: _copy_one_safe SRC DST [METHOD]
# !DESCRIPTION:
#   Safely copy or link a single file from SRC to DST.
#
#   METHOD:
#     - copy     : atomic copy (cp -p to temp, then mv), preserves mode/mtime
#     - hardlink : create a hard link (fails if across filesystems)
#     - symlink  : create/replace a symlink to SRC (absolute target)
#     Aliases: link → hardlink, simlink → symlink
#
#   Behavior:
#     - If DST is an existing directory, the file is placed as DST/basename(SRC).
#     - Parent directory of final destination is created as needed.
#     - Returns non-zero on errors; prints concise error messages to stderr.
#
# !USAGE:
#   _copy_one_safe /data/in/a.bin /data/out copy
#   _copy_one_safe /data/in/a.bin /data/out/another.bin symlink
#   _copy_one_safe /data/in/a.bin /data/out link
#
# !RETURNS:
#   0  ok
#   1  invalid arguments
#   2  source missing or not a regular file
#   3  hardlink across different filesystems
#   4  operation failed (cp/ln/mv errors)
#
# !NOTES:
#   - Portable stat device check (GNU/BSD) to detect cross-FS for hardlink.
#   - Uses absolute SRC path for symlink to avoid broken links when cwd changes.
#EOP
#BOC
_copy_one_safe() {
  _log_debug "→ Entering function: ${FUNCNAME[0]}"
  _with_strict_mode   # enable strict mode only for this function

  local src="${1:-}"; local dst="${2:-}"; local method="${3:-copy}"
  _log_debug "copy_one_safe: src=%s dst=%s method=%s" "${src:-<nil>}" "${dst:-<nil>}" "$method"

  [[ -n "${src}" && -n "${dst}" ]] || { _log_err "copy_one_safe: missing SRC or DST\n" >&2; return 1; }

  # normalize method aliases
  case "${method}" in
    copy|hardlink|symlink) ;;
    link)    method="hardlink" ;;   # alias
    simlink) method="symlink"  ;;   # alias (common typo)
    *) _log_err "copy_one_safe: unknown METHOD '%s' (expected copy|hardlink|symlink)\n" "${method}" >&2; return 1 ;;
  esac

  # source checks
  if [[ ! -e "${src}" ]]; then
    _log_err "copy_one_safe: source does not exist: %s\n" "${src}" >&2
    return 2
  fi
  if [[ ! -f "${src}" ]]; then
    _log_err "copy_one_safe: source is not a regular file: %s\n" "${src}" >&2
    return 2
  fi

  # resolve destination path: if DST is a directory, append basename(SRC)
  local dst_path="${dst}"
  if [[ -d "${dst_path}" ]]; then
    dst_path="${dst%/}/$(basename -- "${src}")"
  fi
  # ensure parent dir exists
  local parent; parent="$(dirname -- "${dst_path}")"
  if [[ "${dry_run:-false}" == true ]]; then
    _log_action "[DRY-RUN] ensure dir: %s" "$parent"
  else
    mkdir -p -- "$parent" || { _log_err "mkdir -p '%s' failed" "$parent"; return 4; }
  fi

  # absolute source path (for symlink target)
  local src_abs; src_abs="$(cd -- "$(dirname -- "${src}")" && pwd)/$(basename -- "${src}")"
  _log_debug "copy_one_safe paths: src_abs=%s final_dst=%s" "$src_abs" "$dst_path"

  # device id helper (GNU/BSD)
  _dev_id() { stat -Lc %d "$1" 2>/dev/null || stat -f %d "$1" 2>/dev/null; }

  case "${method}" in
    copy)
      if [[ "${dry_run:-false}" == true ]]; then
        _log_action "[DRY-RUN] copy %s -> %s" "$src_abs" "$dst_path"
      else
        # atomic-ish copy: cp to temp in same dir, then mv
        local tmp="${dst_path}.tmp.$$"
        # -p preserve mode/mtime; -f overwrite temp if exists
        cp -pf -- "${src_abs}" "${tmp}" 2>/dev/null || { _log_err "cp '%s' -> '%s' failed" "${src_abs}" "${tmp}"; rm -f -- "${tmp}" 2>/dev/null || true; return 4; }
        mv -f -- "${tmp}" "${dst_path}" 2>/dev/null || { _log_err "mv '%s' -> '%s' failed" "${tmp}" "${dst_path}"; rm -f -- "${tmp}" 2>/dev/null || true; return 4; }
      fi
      ;;

    hardlink)
      if [[ "${dry_run:-false}" == true ]]; then
        _log_action "[DRY-RUN] hardlink %s -> %s" "$src_abs" "$dst_path"
      else
        # must be same filesystem
        local sdev ddev
        sdev="$(_dev_id "$(dirname -- "${src_abs}")")" || { _log_err "stat device(src) failed\n" >&2; return 4; }
        ddev="$(_dev_id "$(dirname -- "${dst_path}")")" || { _log_err  "stat device(dst) failed\n" >&2; return 4; }
        if [[ "${sdev}" != "${ddev}" ]]; then
          printf "[ERROR] hardlink across filesystems: %s -> %s\n" "${src_abs}" "${dst_path}" >&2
          return 3
        fi
        ln -f -- "${src_abs}" "${dst_path}" 2>/dev/null || { _log_err "ln (hardlink) failed: %s -> %s\n" "${src_abs}" "${dst_path}" >&2; return 4; }
      fi
      ;;

    symlink)
      if [[ "${dry_run:-false}" == true ]]; then
        _log_action "[DRY-RUN] symlink %s -> %s" "$src_abs" "$dst_path"
      else
        # replace existing file/symlink
        ln -sfn -- "${src_abs}" "${dst_path}" 2>/dev/null || { _log_err "ln -s failed: %s -> %s\n" "${src_abs}" "${dst_path}" >&2; return 4; }
      fi
      ;;
  esac
  
  _log_debug "copy_one_safe done: %s -> %s (%s)" "$src_abs" "$dst_path" "$method"

  return 0
}
#EOC

#BOP
# !FUNCTION: _copy_with_progress
# !INTERFACE: _copy_with_progress <ARRAY_NAME> <SRC_DIR> <DEST_DIR> [ACTION] [MESSAGE]
# !DESCRIPTION:
#   Copy or link a list of files with a clean, minimal progress layout.
#   This implementation draws a TTY progress bar (or emits concise ACTION lines
#   when not attached to a TTY) and avoids rsync entirely. It is ideal when you
#   prefer a compact, consistent look across environments.
#
# !PARAMETERS:
#   ARRAY_NAME  Name of a Bash array variable holding basenames (no [@]).
#   SRC_DIR     Directory where files are read from.
#   DEST_DIR    Directory where files are written to.
#   ACTION      copy (default) | symlink|link|ln|sym | hardlink|hlink|hln
#   MESSAGE     Optional label for progress/log output (default: "Processing files").
#
# !BEHAVIOR:
#   • Respects global flags: dry_run, verbose, debug.
#   • Creates DEST_DIR if needed (mkdir -p).
#   • Progress:
#       - TTY: single-line progress bar via _progress_bar.
#       - Non-TTY: numbered ACTION logs.
#   • Copy semantics:
#       - copy: cp -pf; skips if cmp -s indicates unchanged.
#       - symlink: ln -sfn.
#       - hardlink: ln -f with fallback to copy on cross-device errors.
#
# !RETURNS:
#   0 on success; non-zero on first encountered error.
#
# !NOTES:
#   • Requires Bash 4+ (nameref).
#   • Preferred when you want the lightweight, non-rsync layout.
#EOP
#BOC
_copy_with_progress() {
  _with_strict_mode   # enable strict mode only for this function
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  local -n _files_ref="$1"; shift        # nameref to the input array
  local src_dir="$1"; shift
  local dest_dir="$1"; shift
  local action="${1:-copy}"; shift || true
  local progress_msg="${1:-Processing files}"

  _log_debug "copy_with_progress: action=%s src=%s dest=%s total=%s" "$action" "$src_dir" "$dest_dir" "${#_files_ref[@]}"
  if [[ "${dry_run:-false}" == true ]]; then
    local f; for f in "${_files_ref[@]}"; do
      _log_action "[DRY-RUN] %s %s -> %s" "$action" "${src_dir%/}/$f" "${dest_dir%/}/$f"
    done
    _log_ok "%s: %d/%d processed (dry-run)" "$progress_msg" "${#_files_ref[@]}" "${#_files_ref[@]}"
    return 0
  fi

  mkdir -p -- "$dest_dir" || { _log_err "mkdir -p '%s' failed" "$dest_dir"; return 1; }

  local total=${#_files_ref[@]}
  (( total == 0 )) && { _log_info -f "%s [nothing to do]" "$progress_msg"; return 0; }

  local count=0 f src dst
  for f in "${_files_ref[@]}"; do
    ((count++))
    src="${src_dir%/}/$f"
    dst="${dest_dir%/}/$f"

    if [[ ! -e "$src" ]]; then
      _log_warn "Missing: %s" "$src"
      continue
    fi
    
    # Skip if src and dst are the same file (same inode/device)
    if [[ -e "$dst" ]] && [[ "$src" -ef "$dst" ]]; then
      _log_debug "Same file (skipping): %s" "$dst"
      [[ -t 1 ]] && _progress_bar "$count" "$total" "$progress_msg"
      continue
    fi

    # Show progress/log before executing
    if [[ -t 1 ]]; then
      _progress_bar "$count" "$total" "$progress_msg"
    else
      _log_action -f "(%d/%d) %s -> %s" "$count" "$total" "$src" "$dst"
    fi

    case "$action" in
      copy)
        # If destination exists and contents are identical, skip quietly
        if [[ -e "$dst" ]] && cmp -s -- "$src" "$dst"; then
          _log_debug "Unchanged (skipping): %s" "$dst"
        else
          # Ensure parent dir exists (in case list has subpaths)
          mkdir -p -- "$(dirname -- "$dst")" || { _log_err "mkdir -p '%s' failed" "$(dirname -- "$dst")"; return 1; }
          cp -pf -- "$src" "$dst" || { _log_err "Failed to copy '%s' -> '%s'" "$src" "$dst"; return 1; }
        fi
        ;;
      symlink|link|ln|sym)
        mkdir -p -- "$(dirname -- "$dst")" || { _log_err "mkdir -p '%s' failed" "$(dirname -- "$dst")"; return 1; }
        ln -sfn -- "$src" "$dst" || { _log_err "Failed to symlink '%s' -> '%s'" "$src" "$dst"; return 1; }
        ;;
      hardlink|hlink|hln)
        mkdir -p -- "$(dirname -- "$dst")" || { _log_err "mkdir -p '%s' failed" "$(dirname -- "$dst")"; return 1; }
        # Hard links must be on the same filesystem; if fails, fall back to copy
        if ! ln -f -- "$src" "$dst" 2>/dev/null; then
          _log_warn "Hardlink failed (cross-device?), falling back to copy: %s" "$dst"
          cp -pf -- "$src" "$dst" || { _log_err "Failed to copy '%s' -> '%s' (fallback)" "$src" "$dst"; return 1; }
        fi
        ;;
      *)
        _log_err "Unknown action '%s' (expected: copy|symlink|hardlink)" "$action"
        return 2
        ;;
    esac
  done

  # In TTY, the bar draws inline; append a clean OK marker once.
  if [[ -t 1 ]]; then
    printf " - $C_OK[OK]$C_RST\n"
  else
    _log_ok "%s done" "$progress_msg"
  fi
  return 0
}
#EOC

#BOP
# !FUNCTION: _copy_with_progress_rsync
# !INTERFACE: _copy_with_progress_rsync <array_name> <src_dir> <dest_dir> [copy|link] ["Message"]
# !DESCRIPTION:
#   Copy or link a list of files from a source directory to a destination
#   directory, with progress reporting. Supports two modes:
#     • If `rsync` is available → uses `rsync -a --human-readable --info=progress2`
#       for detailed progress (percentage, bytes, ETA).
#     • If `rsync` is not available → falls back to `_copy_with_progress`
#       which draws a simple progress bar (TTY only).
#   Also supports dry-run mode (global var `dry_run=true`) where operations are
#   only logged, not executed.
#
# !USAGE:
#   files=(file1 file2 file3)
#   _copy_with_progress_ files /path/src /path/dest copy "Copying input files"
#
# !OPTIONS:
#   array_name   Name of the bash array variable containing filenames (not expanded with [@]).
#   src_dir      Source directory containing the files.
#   dest_dir     Destination directory for copy/link.
#   action       Either "copy" (default) or "link".
#   message      Optional label for logging (default: "Copying files").
#
# !BEHAVIOR:
#   • Creates destination directory if missing.
#   • For each file in array:
#       - Verifies existence in src_dir.
#       - Executes copy/link or logs action if dry-run.
#       - Logs progress:
#           · With rsync: clean numeric progress (percentage, size, ETA).
#           · Without rsync: falls back to `_copy_with_progress` (TTY bar).
#   • Reports total processed vs expected at the end.
#
# !NOTES:
#   - Requires `_log_info`, `_log_warn`, `_log_action`, `_log_ok` helpers for logging.
#   - Respects global `dry_run` variable (true/false).
#   - Designed for internal use inside higher-level workflows.
#EOP
#BOC
_copy_with_progress_rsync() {
  _with_strict_mode   # enable strict mode only for this function
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  local files_name="$1"; shift                 # array name (e.g., files), without [@]
  local -n _files_ref="$files_name"            # nameref to iterate here
  local src_dir="$1"; shift
  local dest_dir="$1"; shift
  local action="${1:-copy}"; shift || true
  local progress_msg="${1:-Copying files}"
  local dry="${dry_run:-false}"
  _log_debug "rsync mode: files=%s src=%s dest=%s action=%s dry=%s" "${#_files_ref[@]}" "$src_dir" "$dest_dir" "$action" "$dry"

  if (( ${#_files_ref[@]} == 0 )); then
    _log_info "%s [nothing to do]" "$progress_msg"
    return 0
  fi

  if [[ "$dry" == true ]]; then
    local f
    for f in "${_files_ref[@]}"; do
      _log_action "[DRY-RUN] %s %s -> %s" "$action" "${src_dir%/}/$f" "$dest_dir"
    done
    _log_ok "%s: %d/%d processed (dry-run)" "$progress_msg" "${#_files_ref[@]}" "${#_files_ref[@]}"
    return 0
  fi

  mkdir -p -- "$dest_dir" || { _log_err "mkdir -p failed: %s" "$dest_dir"; return 1; }

  local total=${#_files_ref[@]}
  echo "total: ${total}"
  if (( total == 0 )); then
    _log_info "%s [nothing to do]" "$progress_msg"
    return 0
  fi

  # No rsync: delegate to simple bar (with dry-run handling)
  if ! command -v rsync >/dev/null 2>&1; then
    _log_debug "rsync not found; falling back to simple progress"

    if $dry; then
      local f
      for f in "${_files_ref[@]}"; do
        _log_info "Dry-run: would %s %s -> %s/" "$action" "${src_dir%/}/$f" "$dest_dir"
      done
      _log_ok "%s: %d/%d processed (dry-run)" "$progress_msg" "$total" "$total"
      return 0
    fi
    _copy_with_progress "$files_name" "$src_dir" "$dest_dir" "$action" "$progress_msg"
    return $?
  fi

  # With rsync: show --info=progress2
  local n=0 ok=0 f src dst
  for f in "${_files_ref[@]}"; do
    src="${src_dir%/}/$f"
    dst="${dest_dir%/}/$f"

    if [[ ! -e "$src" ]]; then
      _log_warn "Missing: %s" "$src"
      continue
    fi

    ((n++))
    _log_action "(%d/%d) %s -> %s" "$n" "$total" "$src" "$dst"

    case "$action" in
      copy)
        if rsync -ai --dry-run -- "$src" "$dest_dir"/ | grep -q '^[^\.]'; then
          rsync -a --human-readable --partial \
                --info=progress2,name0 \
                -i --out-format='%i %n' -- "$src" "$dest_dir"/ && ((ok++)) || _log_warn "rsync failed: %s" "$src"
        else
          _log_info "Up-to-date: %s -> %s/" "$src" "$dest_dir"
          ((ok++))
        fi
        ;;
      link)
        if ln -sf -- "$src" "$dst"; then
          ((ok++))
        else
          _log_warn "link failed: %s" "$src"
        fi
        ;;
      *)
        _log_warn "Unknown action: %s (skipping)" "$action"
        ;;
    esac
  done

  _log_ok "%s: %d/%d processed" "$progress_msg" "$ok" "$total"
}
#EOC

#BOP
# !FUNCTION: _copy_with_progress_auto
# !INTERFACE: _copy_with_progress_auto <ARRAY_NAME> <SRC_DIR> <DEST_DIR> [ACTION] [MESSAGE]
# !DESCRIPTION:
#   Convenience wrapper that chooses between the simple layout and the rsync
#   layout without removing either implementation.
#
# !BEHAVIOR:
#   • Honors COPY_BACKEND env var:
#       - "simple" (default): calls _copy_with_progress.
#       - "rsync": calls _copy_with_progress_rsync.
#       - "auto": uses rsync only for ACTION=copy when rsync is available;
#                 otherwise uses the simple layout.
#   • Respects dry_run/verbose/debug through underlying helpers.
#
# !USAGE:
#   COPY_BACKEND=simple _copy_with_progress_auto files ./in ./out copy "Copying"
#   COPY_BACKEND=rsync  _copy_with_progress_auto files ./in ./out copy "Copying"
#   COPY_BACKEND=auto   _copy_with_progress_auto files ./in ./out copy "Copying"
#EOP
#BOC
_copy_with_progress_auto() {
  _with_strict_mode   # enable strict mode only for this function
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  local backend="${COPY_BACKEND:-simple}" action="${4:-copy}"
  case "$backend" in
    rsync) _copy_with_progress_rsync "$@";;
    auto)
      if [[ "$action" == "copy" ]] && command -v rsync >/dev/null 2>&1; then
        _copy_with_progress_rsync "$@"
      else
        _copy_with_progress "$@"
      fi
      ;;
    simple|*) _copy_with_progress "$@";;
  esac
}
#EOC

#BOP
# !FUNCTION: _copy_dir_with_progress
# !INTERFACE: _copy_dir_with_progress <SRC_DIR> <DEST_DIR> [MESSAGE] [ACTION]
# !DESCRIPTION:
#   Copy or link all regular files from <SRC_DIR> into <DEST_DIR>, while
#   delegating file enumeration and progress reporting to existing helpers.
#   This is a thin wrapper that:
#     1) collects basenames from <SRC_DIR> via _list_files_array, then
#     2) calls _copy_with_progress to perform the requested ACTION.
#
# !BEHAVIOR:
#   • Depth: only files at max depth 1 (as implemented by _list_files_array).
#   • ACTION: "copy" (default), "symlink"/"link", or "hardlink" (as supported by
#     _copy_with_progress).
#   • Progress: handled by _copy_with_progress (TTY bar or rsync variant if used
#     elsewhere in your codebase).
#   • dry-run / verbose / debug: respected by the underlying helpers; this
#     wrapper does not change their semantics.
#   • Destination creation: mkdir -p (if needed) is handled inside
#     _copy_with_progress.
#
# !USAGE:
#   _copy_dir_with_progress /path/src /path/dst "Copying inputs" copy
#   _copy_dir_with_progress ./in ./out "Linking files" symlink
#
# !RETURNS:
#   0  on success.
#   >0 propagates the non-zero status from _list_files_array or _copy_with_progress.
#
# !NOTES:
#   • Requires Bash 4+ (the called _copy_with_progress uses nameref).
#   • Filtering (e.g., name patterns) should be done with _list_files_array
#     directly if you need more control; this wrapper collects all regular files.
#EOP
#BOC
_copy_dir_with_progress() {
  _with_strict_mode   # enable strict mode only for this function
  _log_debug "→ Entering function: ${FUNCNAME[0]}"

  local src_dir="$1" dest_dir="$2" msg="${3:-Copying files}" action="${4:-copy}"
  local files=(); _list_files_array files "$src_dir" || return $?
  _copy_with_progress files "$src_dir" "$dest_dir" "$action" "$msg"
}
#EOC


