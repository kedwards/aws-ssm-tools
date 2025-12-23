#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../core/test_guard.sh"

# Single-select menu
# Usage: menu_select_one "Prompt" "Header" result_var "${array[@]}"
guard_function_override menu_select_one || menu_select_one() {
  if non_interactive_mode; then
    log_error "Selection menu not allowed in non-interactive mode"
    return 130
  fi

  local prompt="$1"
  local header="$2"
  local __result_var="$3"
  shift 3
  local items=("$@")

  _menu_validate_result_var "$__result_var" || return 1

  if (( ${#items[@]} == 0 )); then
    log_error "menu_select_one: no items provided"
    return 1
  fi

  log_debug "menu_select_one: prompt='$prompt' header='$header' items_count=${#items[@]}"

  # non-interactive (automation)
  if _menu_non_interactive; then
    if _menu_assume_first; then
      printf -v "$__result_var" '%s' "${items[0]}"
      return 0
    fi
    log_error "Non-interactive mode and no assumption flag set"
    return 1
  fi

  # interactive
  local selection=""
  local fzf_rc=0

  log_debug "Header is '$header' (empty: [[ -z \"$header\" ]])"

  if _menu_use_fzf; then
    selection="$(
      printf '%s\n' "${items[@]}" |
        fzf \
          --prompt="${prompt}: " \
          --header="$header" \
          --height=~50% \
          --reverse \
          --exit-0 \
          --select-1 \
          --ansi \
          --bind=esc:abort
    )"
    fzf_rc=$?

    if [[ $fzf_rc -eq 130 ]]; then
      _menu_cancel
      return 130
    fi

    (( fzf_rc != 0 )) && return 1

    if [[ -z "$selection" ]]; then
      _menu_cancel
      return 130
    fi
  else
    local old_ps3="${PS3-}"
    PS3="${prompt} ${header} (0=cancel): "

    select sel in "${items[@]}"; do
      case "$REPLY" in
        0)
          PS3="$old_ps3"
          _menu_cancel
          return 130
          ;;
        '') log_warn "Invalid selection" ;;
        *) selection="$sel"; break ;;
      esac
    done
    PS3="$old_ps3"
  fi

  printf -v "$__result_var" '%s' "$selection"
  return 0
}
