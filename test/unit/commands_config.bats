#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWST_EC2_DISABLE_LIVE_CALLS=1
export AWST_AUTH_DISABLE_ASSUME=1

setup() {
  # Stub logging
  log_debug() { :; }
  log_info() { :; }
  log_warn() { :; }
  log_error() { :; }
  export -f log_debug log_info log_warn log_error

  # Set ROOT_DIR for sourcing
  ROOT_DIR="$(pwd)"
  export ROOT_DIR

  # Create temp directory for mock config files
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  # Create config directory
  mkdir -p "$HOME/.config/aws-tools/commands/ssm"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_HOME"

  # Clean up command arrays
  unset COMMAND_NAMES COMMAND_DESCRIPTIONS COMMAND_STRINGS
}

# awst_load_ssm_commands tests

@test "awst_load_ssm_commands returns false when no command files exist" {
  source ./lib/core/commands.sh

  run awst_load_ssm_commands
  [ "$status" -eq 1 ]
}

@test "awst_load_ssm_commands loads from default dir" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.config/aws-tools/commands/ssm/memory-info"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 2 ]

  # Find disk-usage
  local i
  for i in "${!COMMAND_NAMES[@]}"; do
    if [[ "${COMMAND_NAMES[$i]}" == "disk-usage" ]]; then
      [ "${COMMAND_DESCRIPTIONS[$i]}" = "Check disk usage" ]
      [ "${COMMAND_STRINGS[$i]}" = "df -h" ]
      return 0
    fi
  done
  return 1
}

@test "awst_load_ssm_commands loads from user dir" {
  printf '# Custom command\necho hello\n' > "$HOME/.config/aws-tools/commands/ssm/custom-cmd"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_NAMES[0]}" = "custom-cmd" ]
}

@test "awst_load_ssm_commands loads from custom dir via env var" {
  local custom_dir="$TEST_HOME/custom-commands"
  mkdir -p "$custom_dir"
  printf '# My command\nls -la\n' > "$custom_dir/my-cmd"

  export AWST_SSM_CMD_DIR="$custom_dir"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_NAMES[0]}" = "my-cmd" ]
}

@test "awst_load_ssm_commands skips files with only comments" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.config/aws-tools/commands/ssm/memory-info"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 2 ]
}

@test "awst_load_ssm_commands loads multiple commands from default dir" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.config/aws-tools/commands/ssm/memory-info"
  printf '# Custom command\necho hello\n' > "$HOME/.config/aws-tools/commands/ssm/custom-cmd"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 3 ]
}

@test "awst_load_ssm_commands handles multi-line command bodies" {
  printf '# Search logs\ngrep ERROR /var/log/app.log | tail -20\n' > "$HOME/.config/aws-tools/commands/ssm/grep-logs"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_STRINGS[0]}" = "grep ERROR /var/log/app.log | tail -20" ]
}

@test "awst_load_ssm_commands handles files with shebang" {
  printf '#!/usr/bin/env bash\n# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"

  source ./lib/core/commands.sh

  awst_load_ssm_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_DESCRIPTIONS[0]}" = "Check disk usage" ]
  [ "${COMMAND_STRINGS[0]}" = "df -h" ]
}

# awst_select_ssm_command tests

@test "awst_select_ssm_command returns false when no commands exist" {
  source ./lib/core/commands.sh

  run awst_select_ssm_command result
  [ "$status" -eq 1 ]
}

@test "awst_select_ssm_command returns selected command" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.config/aws-tools/commands/ssm/memory-info"

  # Mock menu_select_one to select first item
  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "disk-usage: Check disk usage"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  awst_select_ssm_command result
  [ "$result" = "df -h" ]
}

@test "awst_select_ssm_command returns error when menu cancelled" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"

  # Mock menu_select_one to return error (cancelled)
  menu_select_one() {
    return 1
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  run awst_select_ssm_command result
  [ "$status" -eq 1 ]
}

@test "awst_select_ssm_command handles command with spaces" {
  printf '# List all files\nls -la /var/log\n' > "$HOME/.config/aws-tools/commands/ssm/list-files"

  # Mock menu_select_one
  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "list-files: List all files"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  awst_select_ssm_command result
  [ "$result" = "ls -la /var/log" ]
}

@test "awst_select_ssm_command displays commands with descriptions" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.config/aws-tools/commands/ssm/memory-info"

  # Mock menu_select_one to capture display items
  menu_select_one() {
    local prompt="$1"
    local result_var="$3"
    shift 3
    local items=("$@")

    # Verify format is "name: description"
    [ "${items[0]}" = "disk-usage: Check disk usage" ]
    [ "${items[1]}" = "memory-info: Display memory information" ]

    printf -v "$result_var" '%s' "${items[0]}"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  awst_select_ssm_command result
  [ "$result" = "df -h" ]
}
