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
