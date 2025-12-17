#!/usr/bin/env bash
# Interaction & safety guards

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

require_interactive() {
  local reason="${1:-Operation not allowed in non-interactive mode}"

  if ! is_interactive; then
    log_error "$reason"
    log_error "Hint: run without --yes/--dry-run or from an interactive shell"
    return 1
  fi
}

non_interactive_mode() {
  # Explicitly forced non-interactive
  [[ "${ASSUME_YES:-0}" == "1" ]] && return 1
  [[ "${MENU_NON_INTERACTIVE:-0}" == "1" ]] && return 0

  # CI environments
  [[ "${CI:-}" == "true" ]] && return 0

  # Otherwise interactive (even if no TTY)
  return 1
}

open_browser() {
  local url="$1"

  if non_interactive_mode; then
    log_error "Browser interaction not allowed in non-interactive mode"
    log_error "Open manually: $url"
    return 1
  fi

  xdg-open "$url" >/dev/null 2>&1 || true
}
