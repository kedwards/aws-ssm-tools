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

# Test variable expansion

@test "aws_ssm_select_command expands simple variable" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
echo-user|Echo username|echo \$USER
EOF

  # Mock menu_select_one
  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "echo-user: Echo username"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo testuser" ]
}

@test "aws_ssm_select_command expands multiple variables" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
show-env|Show environment|echo \$USER at \$HOSTNAME
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "show-env: Show environment"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  export HOSTNAME="testhost"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo testuser at testhost" ]
}

@test "aws_ssm_select_command expands braced variables" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
show-path|Show path|echo \${HOME}/bin
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "show-path: Show path"
    return 0
  }
  export -f menu_select_one

  # Use current HOME which is guaranteed to be set
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # Result should start with "echo " and contain the expanded HOME path
  [[ "$result" =~ ^echo\ .*/bin$ ]]
}

@test "aws_ssm_select_command handles command substitution" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
show-date|Show date|echo Today is \$(date +%Y-%m-%d)
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "show-date: Show date"
    return 0
  }
  export -f menu_select_one

  # Mock date command for predictable output
  date() {
    if [[ "$1" == "+%Y-%m-%d" ]]; then
      echo "2025-01-15"
    fi
  }
  export -f date

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo Today is 2025-01-15" ]
}

@test "aws_ssm_select_command handles nested command substitution" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
count-files|Count files|echo \$(ls \$(pwd) | wc -l)
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "count-files: Count files"
    return 0
  }
  export -f menu_select_one

  # Mock pwd command
  pwd() {
    echo "/tmp"
  }
  
  # Mock ls command
  ls() {
    if [[ "$1" == "/tmp" ]]; then
      echo "file1"
      echo "file2"
      echo "file3"
    fi
  }
  
  # Mock wc command
  wc() {
    if [[ "$1" == "-l" ]]; then
      echo "3"
    fi
  }
  
  export -f pwd ls wc

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo 3" ]
}

@test "aws_ssm_select_command preserves literal backslash-escaped dollar signs" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
show-price|Show price|echo Price: \\\$100
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "show-price: Show price"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # The \$ in the config should become $100 in output
  [[ "$result" =~ \$100 ]]
}

@test "aws_ssm_select_command expands variables while preserving quotes" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
grep-user|Grep user|grep "\$USER" /etc/passwd
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "grep-user: Grep user"
    return 0
  }
  export -f menu_select_one

  export USER="testuser"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  # The command should expand the variable and contain testuser
  [[ "$result" =~ testuser ]]
  [[ "$result" =~ /etc/passwd ]]
}

@test "aws_ssm_select_command handles backtick command substitution" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
show-hostname|Show hostname|echo Host: \`hostname\`
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "show-hostname: Show hostname"
    return 0
  }
  export -f menu_select_one

  # Mock hostname command
  hostname() {
    echo "testhost"
  }
  export -f hostname

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo Host: testhost" ]
}

@test "aws_ssm_select_command expands arithmetic expansion" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
calc|Calculate|echo \$((2 + 2))
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "calc: Calculate"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo 4" ]
}

@test "aws_ssm_select_command handles complex nested substitution" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
complex|Complex command|echo \$(whoami)@\$(hostname):\$(pwd)
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "complex: Complex command"
    return 0
  }
  export -f menu_select_one

  # Mock commands
  whoami() {
    echo "testuser"
  }
  
  hostname() {
    echo "testhost"
  }
  
  pwd() {
    echo "/home/testuser"
  }
  
  export -f whoami hostname pwd

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "echo testuser@testhost:/home/testuser" ]
}

@test "aws_ssm_select_command expands simple string without variables" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
uptime|Show uptime|uptime
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "uptime: Show uptime"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "uptime" ]
}

@test "aws_ssm_select_command expands command with pipes and variables" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
grep-logs|Grep logs|grep \$PATTERN /var/log/app.log | tail -10
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "grep-logs: Grep logs"
    return 0
  }
  export -f menu_select_one

  export PATTERN="ERROR"
  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "grep ERROR /var/log/app.log | tail -10" ]
}

@test "aws_ssm_select_command preserves structure with conditional" {
  cat > "$HOME/.local/share/aws-ssm-tools/commands.config" <<EOF
conditional|Conditional check|[ -f /tmp/test ] && echo exists || echo missing
EOF

  menu_select_one() {
    local result_var="$3"
    printf -v "$result_var" '%s' "conditional: Conditional check"
    return 0
  }
  export -f menu_select_one

  source ./lib/core/commands.sh
  
  local result
  aws_ssm_select_command result
  [ "$result" = "[ -f /tmp/test ] && echo exists || echo missing" ]
}
