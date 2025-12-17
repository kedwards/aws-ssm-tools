#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../core/test_guard.sh"

# Multi-select menu
# Usage: menu_select_many "Prompt" "Header" result_array "${array[@]}"
guard_function_override menu_select_many || menu_select_many() {
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
    log_error "menu_select_many: no items provided"
    return 1
  fi

  local selections=()
  local fzf_rc=0

  # non-interactive (automation)
  if _menu_non_interactive; then
    if _menu_assume_all; then
      printf -v "$__result_var" '%s\n' "${items[@]}"
      return 0
    fi
    log_error "Non-interactive mode and no assumption flag set"
    return 1
  fi

  # interactive
  if _menu_use_fzf; then
    mapfile -t selections < <(
      printf '%s\n' "${items[@]}" |
        fzf \
          --multi \
          --prompt="${prompt}: " \
          --header="$header" \
          --height=50% \
          --reverse \
          --exit-0 \
          --ansi \
          --bind=esc:abort
    )
    fzf_rc=$?

    if [[ $fzf_rc -eq 130 ]]; then
      _menu_cancel
      return 130
    fi

    (( fzf_rc != 0 )) && return 1

    if (( ${#selections[@]} == 0 )); then
      _menu_cancel
      return 130
    fi
  else
    local old_ps3="${PS3-}"
    PS3="${prompt} ${header} (space-separated numbers, 0=cancel): "

    select _ in "${items[@]}"; do
      case "$REPLY" in
        0)
          PS3="$old_ps3"
          _menu_cancel
          return 130
          ;;
        *)
          for idx in $REPLY; do
            (( idx >= 1 && idx <= ${#items[@]} )) &&
              selections+=( "${items[idx-1]}" )
          done
          (( ${#selections[@]} )) && break
          log_warn "No valid selections"
          ;;
      esac
    done
    PS3="$old_ps3"
  fi

  printf -v "$__result_var" '%s\n' "${selections[@]}"
  return 0
}
