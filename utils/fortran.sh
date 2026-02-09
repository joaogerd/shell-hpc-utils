#!/usr/bin/env bash
#BOP
#
# !FUNCTION: bool_to_fortran
#
# !INTERFACE:
#   bool_to_fortran <true|false>
#
# !DESCRIPTION:
#   Convert a shell boolean-like value into a Fortran logical literal.
#   The function accepts case-insensitive "true" to return ".TRUE." and
#   any other value (including empty) to return ".FALSE.".
#
# !USAGE:
#   bool_to_fortran true     # -> .TRUE.
#   bool_to_fortran false    # -> .FALSE.
#   bool_to_fortran          # -> .FALSE. (default)
#
# !RETURNS:
#   Writes either ".TRUE." or ".FALSE." to stdout (no trailing newline change).
#
# !EXAMPLES:
#   export DRY_RUN=true
#   fflag="$(bool_to_fortran "${DRY_RUN}")"
#   printf "Fortran flag: %s\n" "${fflag}"
#
# !DEPENDENCIES:
#   Bash 4+ (for general script environment). Uses only built-in shell features.
#
# !NOTES:
#   - Input is matched case-insensitively. Only values that look like "true"
#     (e.g., "TRUE", "True") are considered true.
#
#EOP
#BOC
bool_to_fortran() {
  case "${1:-false}" in
    [Tt][Rr][Uu][Ee])  printf '.TRUE.'  ;;
    *)                 printf '.FALSE.' ;;
  esac
}
#EOC

