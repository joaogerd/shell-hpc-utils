#!/usr/bin/env bash
#BOP
# !FUNCTION: _assign
# !INTERFACE: _assign <KEY> <VALUE...>
# !DESCRIPTION:
#   Define and export an environment variable from a KEY and VALUE pair,
#   expanding ${VAR} references using the current environment and variables
#   already set by previous _assign calls.
#
# !USAGE:
#   _assign HOME /home/${USER}
#   _assign subt_smg ${SUBMIT_HOME}/${nome_smg}
#
# !BEHAVIOR:
#   • Joins VALUE arguments into a single string
#   • Expands variable references like ${USER}, ${SUBMIT_HOME}
#   • If `envsubst` is available, uses it for expansion
#   • Otherwise, uses a safe eval/printf fallback (disallows command substitution)
#   • Exports KEY=expanded_value to the shell environment
#
# !NOTES:
#   • Order matters: referenced variables must be defined earlier
#   • Does not allow backticks, $(), or arithmetic $(( )) substitutions
#EOP
#BOC
_assign() {
  local key="${1:?KEY required}"; shift
  # Join VALUE... preserving internal spaces
  local raw="$*"

  # Safe expansion using envsubst, if available
  if command -v envsubst >/dev/null 2>&1; then
    local expanded
    if ! expanded="$(printf '%s' "$raw" | envsubst)"; then
      _log_err "_assign: envsubst failed for %s" "$key"; return 1
    fi
    export "$key=$expanded"
    _log_debug "_assign: %s=%q (len=%d)" "$key" "$expanded" "${#expanded}"
    return 0
  fi

  # Fallback without envsubst: block command substitution
  if printf '%s' "$raw" | grep -Eq '(`|\$\(|\$\(\()'; then
    _log_err "_assign: forbidden command substitution in value for $key" >&2
    return 1
  fi

  # Perform only variable expansion ${VAR} / $VAR using eval+printf
  # shellcheck disable=SC2086
  local expanded
  expanded="$(eval "printf '%s' \"$raw\"")" || { _log_err "_assign: eval failed for %s" "$key"; return 1; }
  export "$key=$expanded"
  _log_debug "_assign: %s=%q (len=%d)" "$key" "$expanded" "${#expanded}"
}
#EOC

#BOP
# !FUNCTION: _strip_inline_comment
# !DESCRIPTION:
#   Removes inline comments starting with '#' that are *not* enclosed within double quotes.
#   It preserves everything within quotes, even if it contains '#'.
#
# !INPUTS:
#   $1 : String possibly containing inline comments and quoted substrings.
#
# !OUTPUTS:
#   Prints the string without the comment part (trims trailing spaces).
#
# !EXAMPLES:
#   Input : 'VAR "abc#123"   # comment'
#   Output: 'VAR "abc#123"'
#
# !NOTES:
#   - Supports escaped quotes (\"), so sequences like '\"' don't toggle quote state.
#   - Trims trailing whitespace after comment removal.
#EOP
#BOP
_strip_inline_comment() {
  local s="${1-}" out="" inquote=0 prev='' c
  local i

  # Iterate through each character
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"

    # Toggle quote state when encountering an unescaped double quote
    if [[ "$c" == '"' && "$prev" != '\' ]]; then
      (( inquote = 1 - inquote ))
      out+="$c"
    # If '#' is found outside quotes, stop (comment begins here)
    elif [[ "$c" == '#' && $inquote -eq 0 ]]; then
      break
    else
      out+="$c"
    fi
    prev="$c"
  done

  # Trim trailing spaces
  printf '%s' "${out%"${out##*[![:space:]]}"}"
}
#EOC

