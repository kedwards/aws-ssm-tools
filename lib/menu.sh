#!/usr/bin/env bash

# Select a single item from stdin or array
# Usage: menu_select_one "Prompt" "Header" result_var "${array[@]}"
menu_select_one() {
  local prompt="$1"
  local header="$2"
  local __result_var="$3"
  shift 3
  local items=("$@")

  if [[ ${#items[@]} -eq 0 ]]; then
    log_error "No items to select from in menu_select_one"
    return 1
  fi

  local selection=""
  if command -v fzf >/dev/null 2>&1; then
    selection=$(printf '%s\n' "${items[@]}" | fzf --prompt="${prompt}: " --height=~50% --reverse --header="${header}")
    if [[ -z "$selection" ]]; then
      log_info "No selection made (fzf cancelled)"
      return 1
    fi
  else
    PS3="${prompt} ${header} (0 to cancel): "
    select sel in "${items[@]}"; do
      if [[ "$REPLY" == "0" ]]; then
        log_info "Selection cancelled"
        return 1
      elif [[ -z "$sel" ]]; then
        echo "\"$REPLY\" is not a valid choice" >&2
      else
        selection="$sel"
        break
      fi
    done
  fi

  printf -v "$__result_var" '%s' "$selection"
  return 0
}

# Multi-select using fzf; falls back to single-select loop if fzf missing
# Usage: menu_select_multi "Prompt" result_var "${array[@]}"
menu_select_multi() {
  local prompt="$1"
  local __result_var="$2"
  shift 2
  local items=("$@")

  if [[ ${#items[@]} -eq 0 ]]; then
    log_error "No items to select from in menu_select_multi"
    return 1
  fi

  local selections=""
  if command -v fzf >/dev/null 2>&1; then
    # Make Enter select current item if nothing marked, then accept
    # {+} gives all selected items, {q} gives the query, {} gives current item
    selections=$(printf '%s\n' "${items[@]}" |
      fzf --multi --prompt="${prompt}: " --height=50% --reverse \
        --header="${prompt} (Tab to mark multiple, Enter to confirm)" \
        --bind 'enter:become(printf "%s\n" {+})')
    local fzf_exit=$?
    if [[ -z "$selections" ]]; then
      log_info "No selection made (fzf cancelled)"
      return 1
    fi
  else
    log_warn "fzf not installed; using single-select menu (repeat to select multiple)"
    local chosen=()
    while true; do
      PS3="${prompt} (0 to finish): "
      select sel in "${items[@]}"; do
        if [[ "$REPLY" == "0" ]]; then
          selections=$(printf '%s\n' "${chosen[@]}")
          break 2
        elif [[ -z "$sel" ]]; then
          echo "\"$REPLY\" is not a valid choice" >&2
        else
          chosen+=("$sel")
          break
        fi
      done
    done
  fi

  # Use printf -v to set in caller's scope
  printf -v "$__result_var" '%s' "$selections"
  return 0
}
