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
  mkdir -p "$HOME/.local/share/aws-ssm-tools"
  mkdir -p "$HOME/.config/aws-ssm-tools"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_HOME"
  
  # Clean up command arrays
  unset COMMAND_NAMES COMMAND_DESCRIPTIONS COMMAND_STRINGS
}

# aws_ssm_load_commands tests

@test "aws_ssm_load_commands returns false when no config files exist" {
  source ./lib/core/commands.sh
  
  run aws_ssm_load_commands
  [ "$status" -eq 1 ]
}

@test "aws_ssm_load_commands loads from default config" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
disk-usage|Check disk usage|df -h
memory-info|Display memory information|free -h
EOF

  source ./lib/core/commands.sh
  
  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 2 ]
  [ "${COMMAND_NAMES[0]}" = "disk-usage" ]
  [ "${COMMAND_DESCRIPTIONS[0]}" = "Check disk usage" ]
  [ "${COMMAND_STRINGS[0]}" = "df -h" ]
}

@test "aws_ssm_load_commands loads from user config" {
  cat > "$HOME/.config/aws-ssm-tools/commands.user.config" <<EOF
custom-cmd|Custom command|echo hello
EOF

  source ./lib/core/commands.sh
  
  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_NAMES[0]}" = "custom-cmd" ]
}

@test "aws_ssm_load_commands loads from custom config via env var" {
  cat > "$HOME/custom.config" <<EOF
my-cmd|My command|ls -la
EOF

  export AWS_SSM_COMMAND_FILE="$HOME/custom.config"
  
  source ./lib/core/commands.sh
  
  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_NAMES[0]}" = "my-cmd" ]
}

@test "aws_ssm_load_commands ignores comment lines" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
# This is a comment
disk-usage|Check disk usage|df -h
# Another comment
memory-info|Display memory information|free -h
EOF

  source ./lib/core/commands.sh
  
  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 2 ]
}

@test "aws_ssm_load_commands ignores empty lines" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
disk-usage|Check disk usage|df -h

memory-info|Display memory information|free -h

EOF

  source ./lib/core/commands.sh
  
  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 2 ]
}

@test "aws_ssm_load_commands merges configs with user overriding default" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
disk-usage|Check disk usage|df -h
memory-info|Display memory information|free -h
EOF

  cat > "$HOME/.config/aws-ssm-tools/commands.user.config" <<EOF
disk-usage|Custom disk check|df -H
custom-cmd|Custom command|echo hello
EOF

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

@test "aws_ssm_load_commands handles pipes in command strings" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
grep-logs|Search logs|grep ERROR /var/log/app.log | tail -20
EOF

  source ./lib/core/commands.sh
  
  aws_ssm_load_commands
  [ "${#COMMAND_NAMES[@]}" -eq 1 ]
  [ "${COMMAND_STRINGS[0]}" = "grep ERROR /var/log/app.log | tail -20" ]
}

# aws_ssm_select_command tests

@test "aws_ssm_select_command returns false when no commands exist" {
  source ./lib/core/commands.sh
  
  run aws_ssm_select_command result
  [ "$status" -eq 1 ]
}

@test "aws_ssm_select_command returns selected command" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
disk-usage|Check disk usage|df -h
memory-info|Display memory information|free -h
EOF

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

@test "aws_ssm_select_command expands variables in command" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
echo-var|Echo variable|echo \$USER
EOF

  # Mock menu_select_one
  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "echo-var: Echo variable"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo testuser" ]
}

@test "aws_ssm_select_command returns error when menu cancelled" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
disk-usage|Check disk usage|df -h
EOF

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
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
list-files|List all files|ls -la /var/log
EOF

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
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
disk-usage|Check disk usage|df -h
memory-info|Display memory information|free -h
EOF

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
