#!/usr/bin/env bats
# shellcheck disable=SC2034
# Tests that command file bodies are returned as-is (no local expansion).
# Commands are sent to remote instances for execution — expansion happens there.

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

  ROOT_DIR="$(pwd)"
  export ROOT_DIR

  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  mkdir -p "$HOME/.config/aws-tools/commands/ssm"
  mkdir -p "$HOME/.config/aws-tools/commands/ssm"
}

teardown() {
  rm -rf "$TEST_HOME"
  unset COMMAND_NAMES COMMAND_DESCRIPTIONS COMMAND_STRINGS
}

# Helper: write command file and mock menu to select it
_setup_select() {
  local name="$1" desc="$2" body="$3"
  printf '# %s\n%s\n' "$desc" "$body" > "$HOME/.config/aws-tools/commands/ssm/$name"
  menu_select_one() {
    local result_var="$3"
    shift 3
    printf -v "$result_var" '%s' "$1"  # select first item
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh
}

@test "returns simple command as-is" {
  _setup_select "uptime" "Show uptime" "uptime"
  local result
  awst_select_ssm_command result
  [ "$result" = "uptime" ]
}

@test "preserves variable references without expanding" {
  printf '# Echo username\necho $USER\n' > "$HOME/.config/aws-tools/commands/ssm/echo-user"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  awst_select_ssm_command result
  [[ "$result" == *'$USER'* ]]
}

@test "preserves command substitution syntax" {
  printf '# Show date\necho Today is $(date +%%Y-%%m-%%d)\n' > "$HOME/.config/aws-tools/commands/ssm/show-date"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  awst_select_ssm_command result
  [[ "$result" =~ \$\( ]]
}

@test "preserves pipes in command body" {
  _setup_select "grep-logs" "Search logs" "grep ERROR /var/log/app.log | tail -10"
  local result
  awst_select_ssm_command result
  [ "$result" = "grep ERROR /var/log/app.log | tail -10" ]
}

@test "preserves conditionals in command body" {
  _setup_select "conditional" "Conditional check" "[ -f /tmp/test ] && echo exists || echo missing"
  local result
  awst_select_ssm_command result
  [ "$result" = "[ -f /tmp/test ] && echo exists || echo missing" ]
}

@test "preserves redirections" {
  _setup_select "redirect" "Redirect output" "echo test > /tmp/output.txt 2>&1"
  local result
  awst_select_ssm_command result
  [ "$result" = "echo test > /tmp/output.txt 2>&1" ]
}

@test "preserves semicolon-separated commands" {
  _setup_select "multi-cmd" "Multiple commands" "cd /tmp; ls -la; pwd"
  local result
  awst_select_ssm_command result
  [ "$result" = "cd /tmp; ls -la; pwd" ]
}

@test "preserves glob patterns" {
  _setup_select "glob-pattern" "Glob pattern" "ls /var/log/*.log"
  local result
  awst_select_ssm_command result
  [ "$result" = "ls /var/log/*.log" ]
}

@test "handles multi-line command body" {
  printf '# Multi-line\nif [ -f /tmp/x ]; then\n  echo found\nfi\n' > "$HOME/.config/aws-tools/commands/ssm/multi-line"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  awst_select_ssm_command result
  # Body should contain the if/then/fi structure
  [[ "$result" =~ "if " ]]
  [[ "$result" =~ "fi" ]]
}
