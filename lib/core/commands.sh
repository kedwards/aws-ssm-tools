#!/usr/bin/env bash

# Global arrays to store loaded commands
COMMAND_NAMES=()
COMMAND_DESCRIPTIONS=()
COMMAND_STRINGS=()

aws_ssm_load_commands() {
  local default_config="$HOME/.local/share/aws-ssm-tools/commands.config"
  local user_config="$HOME/.config/aws-ssm-tools/commands.user.config"
  local custom_config="${AWS_SSM_COMMAND_FILE:-}"

  # Reset arrays
  COMMAND_NAMES=()
  COMMAND_DESCRIPTIONS=()
  COMMAND_STRINGS=()

  # Helper function to load from a single file
  _load_from_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    while IFS='|' read -r name desc cmd; do
      # Skip empty lines
      [[ -z "$name" ]] && continue
      
      # Skip comments
      [[ "$name" =~ ^# ]] && continue

      # Check if command name already exists (override)
      local i found=false
      for i in "${!COMMAND_NAMES[@]}"; do
        if [[ "${COMMAND_NAMES[$i]}" == "$name" ]]; then
          COMMAND_DESCRIPTIONS[$i]="$desc"
          COMMAND_STRINGS[$i]="$cmd"
          found=true
          break
        fi
      done

      # Add new command if not found
      if [[ "$found" == false ]]; then
        COMMAND_NAMES+=("$name")
        COMMAND_DESCRIPTIONS+=("$desc")
        COMMAND_STRINGS+=("$cmd")
      fi
    done < "$file"
  }

  # Load configs in order (later files override earlier ones)
  _load_from_file "$default_config"
  _load_from_file "$user_config"
  [[ -n "$custom_config" && -f "$custom_config" ]] && _load_from_file "$custom_config"

  # Return success if any commands were loaded
  (( ${#COMMAND_NAMES[@]} > 0 ))
}

aws_ssm_select_command() {
  local __result_var="$1"

  # Load commands
  if ! aws_ssm_load_commands; then
    log_warn "No saved commands found"
    return 1
  fi

  # Build display list (name: description)
  local display=()
  local i
  for i in "${!COMMAND_NAMES[@]}"; do
    display+=("${COMMAND_NAMES[$i]}: ${COMMAND_DESCRIPTIONS[$i]}")
  done

  # Interactive selection
  local selected
  if ! menu_select_one "Select saved command" "Saved Commands" selected "${display[@]}"; then
    return 1
  fi

  # Extract command name from selection (before the colon)
  local selected_name="${selected%%:*}"

  # Find and return the command string
  for i in "${!COMMAND_NAMES[@]}"; do
    if [[ "${COMMAND_NAMES[$i]}" == "$selected_name" ]]; then
      local cmd="${COMMAND_STRINGS[$i]}"
      # Expand variables in command
      cmd=$(eval "echo \"$cmd\"")
      printf -v "$__result_var" '%s' "$cmd"
      return 0
    fi
  done

  log_error "Command '$selected_name' not found in list"
  return 1
}
