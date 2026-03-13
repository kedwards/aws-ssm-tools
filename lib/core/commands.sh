#!/usr/bin/env bash

# Default commands/ssm directories
_AWST_SSM_CMD_INSTALL_DIR="${HOME}/.local/share/aws-tools/commands/ssm"
_AWST_SSM_CMD_USER_DIR="${HOME}/.config/aws-tools/commands/ssm"

# Global arrays to store loaded commands
COMMAND_NAMES=()
COMMAND_DESCRIPTIONS=()
COMMAND_STRINGS=()

# Parse a command file: extract description (first comment line) and body
_parse_command_file() {
  local file="$1"
  local __desc_var="$2"
  local __body_var="$3"

  local _d="" _b="" _line _first=true
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    # Skip shebang
    [[ "$_line" == "#!"* ]] && continue
    # First comment line is the description
    if $_first && [[ "$_line" =~ ^#\ *(.*) ]]; then
      _d="${BASH_REMATCH[1]}"
      _first=false
      continue
    fi
    _first=false
    # Skip remaining comments and blank lines
    [[ "$_line" =~ ^# ]] && continue
    [[ -z "$_line" ]] && continue
    # Accumulate body
    if [[ -n "$_b" ]]; then
      _b="${_b}
${_line}"
    else
      _b="$_line"
    fi
  done < "$file"

  printf -v "$__desc_var" '%s' "$_d"
  printf -v "$__body_var" '%s' "$_b"
}

awst_load_ssm_commands() {
  local custom_dir="${AWST_SSM_CMD_DIR:-}"

  # Reset arrays
  COMMAND_NAMES=()
  COMMAND_DESCRIPTIONS=()
  COMMAND_STRINGS=()

  # Helper function to load all commands from a directory
  _load_from_dir() {
    local dir="$1"
    [[ ! -d "$dir" ]] && return 0

    local f name desc body
    for f in "$dir"/*; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      _parse_command_file "$f" desc body

      # Check if command name already exists (override)
      local i found=false
      for i in "${!COMMAND_NAMES[@]}"; do
        if [[ "${COMMAND_NAMES[$i]}" == "$name" ]]; then
          COMMAND_DESCRIPTIONS[$i]="$desc"
          COMMAND_STRINGS[$i]="$body"
          found=true
          break
        fi
      done

      # Add new command if not found
      if [[ "$found" == false ]]; then
        COMMAND_NAMES+=("$name")
        COMMAND_DESCRIPTIONS+=("$desc")
        COMMAND_STRINGS+=("$body")
      fi
    done
  }

  # Load dirs in order (later dirs override earlier ones)
  _load_from_dir "$_AWST_SSM_CMD_INSTALL_DIR"
  _load_from_dir "$_AWST_SSM_CMD_USER_DIR"
  [[ -n "$custom_dir" && -d "$custom_dir" ]] && _load_from_dir "$custom_dir"

  # Return success if any commands were loaded
  (( ${#COMMAND_NAMES[@]} > 0 ))
}

awst_select_ssm_command() {
  local __result_var="$1"

  # Load commands
  if ! awst_load_ssm_commands; then
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
      printf -v "$__result_var" '%s' "$cmd"
      return 0
    fi
  done

  log_error "Command '$selected_name' not found in list"
  return 1
}
