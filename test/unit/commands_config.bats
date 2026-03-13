#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

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

  # Create config directories
  mkdir -p "$HOME/.local/share/aws-tools/commands/ssm"
  mkdir -p "$HOME/.config/aws-tools/commands/ssm"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_HOME"

  # Clean up command arrays
  unset COMMAND_NAMES COMMAND_DESCRIPTIONS COMMAND_STRINGS
}

# aws_ssm_load_commands tests

@test "aws_ssm_load_commands returns false when no command files exist" {
  source ./lib/core/commands.sh

  run aws_ssm_load_commands
  [ "$status" -eq 1 ]
}

@test "aws_ssm_load_commands loads from default install dir" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/memory-info"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
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

@test "aws_ssm_load_commands loads from user dir" {
  printf '# Custom command\necho hello\n' > "$HOME/.config/aws-tools/commands/ssm/custom-cmd"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_NAMES[0]}" = "custom-cmd" ]
}

@test "aws_ssm_load_commands loads from custom dir via env var" {
  local custom_dir="$TEST_HOME/custom-commands"
  mkdir -p "$custom_dir"
  printf '# My command\nls -la\n' > "$custom_dir/my-cmd"

  export AWS_SSM_COMMAND_DIR="$custom_dir"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_NAMES[0]}" = "my-cmd" ]
}

@test "aws_ssm_load_commands skips files with only comments" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/memory-info"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 2 ]
}

@test "aws_ssm_load_commands merges dirs with user overriding default" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/memory-info"

  printf '# Custom disk check\ndf -H\n' > "$HOME/.config/aws-tools/commands/ssm/disk-usage"
  printf '# Custom command\necho hello\n' > "$HOME/.config/aws-tools/commands/ssm/custom-cmd"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 3 ]

  # Find disk-usage (should be overridden)
  local i
  for i in "${!COMMAND_NAMES[@]}"; do
    if [[ "${COMMAND_NAMES[$i]}" == "disk-usage" ]]; then
      [ "${COMMAND_DESCRIPTIONS[$i]}" = "Custom disk check" ]
      [ "${COMMAND_STRINGS[$i]}" = "df -H" ]
      break
    fi
  done
}

@test "aws_ssm_load_commands handles multi-line command bodies" {
  printf '# Search logs\ngrep ERROR /var/log/app.log | tail -20\n' > "$HOME/.local/share/aws-tools/commands/ssm/grep-logs"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_STRINGS[0]}" = "grep ERROR /var/log/app.log | tail -20" ]
}

@test "aws_ssm_load_commands handles files with shebang" {
  printf '#!/usr/bin/env bash\n# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"

  source ./lib/core/commands.sh

  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_DESCRIPTIONS[0]}" = "Check disk usage" ]
  [ "${COMMAND_STRINGS[0]}" = "df -h" ]
}

# aws_ssm_select_command tests

@test "aws_ssm_select_command returns false when no commands exist" {
  source ./lib/core/commands.sh

  run aws_ssm_select_command result
  [ "$status" -eq 1 ]
}

@test "aws_ssm_select_command returns selected command" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/memory-info"

  # Mock menu_select_one to select first item
  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "disk-usage: Check disk usage"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [ "$result" = "df -h" ]
}

@test "aws_ssm_select_command returns error when menu cancelled" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"

  # Mock menu_select_one to return error (cancelled)
  menu_select_one() {
    return 1
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  run aws_ssm_select_command result
  [ "$status" -eq 1 ]
}

@test "aws_ssm_select_command handles command with spaces" {
  printf '# List all files\nls -la /var/log\n' > "$HOME/.local/share/aws-tools/commands/ssm/list-files"

  # Mock menu_select_one
  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "list-files: List all files"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [ "$result" = "ls -la /var/log" ]
}

@test "aws_ssm_select_command displays commands with descriptions" {
  printf '# Check disk usage\ndf -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/disk-usage"
  printf '# Display memory information\nfree -h\n' > "$HOME/.local/share/aws-tools/commands/ssm/memory-info"

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
  aws_ssm_select_command result
  [ "$result" = "df -h" ]
}
