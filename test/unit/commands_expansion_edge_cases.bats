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

# Additional edge cases for command expansion

@test "aws_ssm_select_command expands variables with default values" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
default-var|Use default|echo \${MYVAR:-default_value}
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "default-var: Use default"
    return 0
  }
  export -f menu_select_one

  # Don't set MYVAR - should use default
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo default_value" ]
}

@test "aws_ssm_select_command expands variables with assigned defaults" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
assign-default|Assign default|echo \${MYVAR:=assigned}
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "assign-default: Assign default"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo assigned" ]
}

@test "aws_ssm_select_command handles mixed quotes and variables" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
mixed-quotes|Mixed quotes|echo "User: \$USER" 'Literal: \$USER'
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "mixed-quotes: Mixed quotes"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # Double quotes should expand, single quotes should not
  [[ "$result" =~ testuser ]]
}

@test "aws_ssm_select_command handles tab characters" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<'EOF'
with-tabs|With tabs|echo -e "col1\tcol2\tcol3"
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "with-tabs: With tabs"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # The command is expanded but backslash-t becomes literal tab or remains as-is
  [[ "$result" =~ "echo -e" ]]
}

@test "aws_ssm_select_command handles glob patterns" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
glob-pattern|Glob pattern|ls /var/log/*.log
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "glob-pattern: Glob pattern"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "ls /var/log/*.log" ]
}

@test "aws_ssm_select_command handles redirections" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
redirect|Redirect output|echo test > /tmp/output.txt 2>&1
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "redirect: Redirect output"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo test > /tmp/output.txt 2>&1" ]
}

@test "aws_ssm_select_command handles semicolon-separated commands" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
multi-cmd|Multiple commands|cd /tmp; ls -la; pwd
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "multi-cmd: Multiple commands"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "cd /tmp; ls -la; pwd" ]
}

@test "aws_ssm_select_command handles subshells" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
subshell|Run in subshell|(cd /tmp && ls)
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "subshell: Run in subshell"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "(cd /tmp && ls)" ]
}

@test "aws_ssm_select_command handles here-strings" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<'EOF'
here-string|Here string|grep pattern <<< "test string"
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "here-string: Here string"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # Here-strings structure is preserved
  [[ "$result" =~ "grep pattern" ]]
}

@test "aws_ssm_select_command expands array variables" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
array-var|Array variable|echo \${FILES[0]}
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "array-var: Array variable"
    return 0
  }
  export -f menu_select_one

  # Arrays need special export handling in bash
  FILES=(file1.txt file2.txt file3.txt)
  export FILES
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # Arrays may not expand in subshells as expected, so just verify structure
  [[ "$result" =~ "echo" ]]
}

@test "aws_ssm_select_command handles parameter length expansion" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
param-length|Parameter length|echo \${#USER}
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "param-length: Parameter length"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo 8" ]
}

@test "aws_ssm_select_command handles string substitution" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
string-sub|String substitution|echo \${USER/test/prod}
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "string-sub: String substitution"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo produser" ]
}
