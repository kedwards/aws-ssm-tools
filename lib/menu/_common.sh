#!/usr/bin/env bash

# Common menu helpers
# Flags are STRINGS ("1"/"0"), never arithmetic

_menu_use_fzf() {
  # Explicit override always wins
  if [[ "${MENU_NO_FZF:-}" == "1" ]]; then
    return 1
  fi

  command -v fzf >/dev/null 2>&1
}

_menu_non_interactive() {
  [[ "${MENU_NON_INTERACTIVE:-}" == "1" ]]
}

_menu_assume_first() {
  [[ "${MENU_ASSUME_FIRST:-}" == "1" ]]
}

_menu_assume_all() {
  [[ "${MENU_ASSUME_ALL:-}" == "1" ]]
}

_menu_validate_result_var() {
  local name="$1"

  if [[ -z "$name" ]]; then
    log_error "result variable name is required"
    return 1
  fi

  if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    log_error "invalid variable name '$name'"
    return 1
  fi
}

_menu_cancel() {
  log_info "Selection cancelled"
  return 130
}

