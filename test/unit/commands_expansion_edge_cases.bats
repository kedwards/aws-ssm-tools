#!/usr/bin/env bats
# shellcheck disable=SC2034
# Edge-case tests for file-based command loading.
# Commands are returned as raw text — no local expansion.

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

setup() {
  log_debug() { :; }
  log_info() { :; }
  log_warn() { :; }
  log_error() { :; }
  export -f log_debug log_info log_warn log_error

  ROOT_DIR="$(pwd)"
  export ROOT_DIR

  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  mkdir -p "$HOME/.local/share/aws-ssm-tools/commands/ssm"
  mkdir -p "$HOME/.config/aws-ssm-tools/commands/ssm"
}

teardown() {
  rm -rf "$TEST_HOME"
  unset COMMAND_NAMES COMMAND_DESCRIPTIONS COMMAND_STRINGS
}

# Helper: write command file and mock menu to select it
_setup_select() {
  local name="$1" desc="$2" body="$3"
  printf '# %s\n%s\n' "$desc" "$body" > "$HOME/.local/share/aws-ssm-tools/commands/ssm/$name"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh
}

@test "preserves variable default syntax" {
  printf '# Use default\necho ${MYVAR:-default_value}\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/default-var"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" == *'${MYVAR:-default_value}'* ]]
}

@test "preserves quoted strings" {
  printf '# Mixed quotes\necho "User: $USER" '"'"'Literal: $USER'"'"'\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/mixed-quotes"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" =~ \$USER ]]
}

@test "preserves tab escape sequences" {
  _setup_select "with-tabs" "With tabs" 'echo -e "col1\tcol2\tcol3"'
  local result
  aws_ssm_select_command result
  [[ "$result" =~ "echo -e" ]]
}

@test "preserves subshell syntax" {
  _setup_select "subshell" "Run in subshell" "(cd /tmp && ls)"
  local result
  aws_ssm_select_command result
  [ "$result" = "(cd /tmp && ls)" ]
}

@test "preserves here-string syntax" {
  printf '# Here string\ngrep pattern <<< "test string"\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/here-string"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" =~ "grep pattern" ]]
}

@test "preserves array syntax" {
  printf '# Array variable\necho ${FILES[0]}\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/array-var"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" =~ 'FILES[0]' ]]
}

@test "preserves parameter length syntax" {
  printf '# Parameter length\necho ${#USER}\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/param-length"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" == *'${#USER}'* ]]
}

@test "preserves string substitution syntax" {
  printf '# String substitution\necho ${USER/test/prod}\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/string-sub"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" == *'${USER/test/prod}'* ]]
}

@test "handles command file with extra blank lines between body lines" {
  printf '# Spaced out\necho line1\n\necho line2\n' > "$HOME/.local/share/aws-ssm-tools/commands/ssm/spaced"
  menu_select_one() {
    local result_var="$3"; shift 3
    printf -v "$result_var" '%s' "$1"
    return 0
  }
  export -f menu_select_one
  source ./lib/core/commands.sh

  local result
  aws_ssm_select_command result
  [[ "$result" =~ "echo line1" ]]
  [[ "$result" =~ "echo line2" ]]
}
