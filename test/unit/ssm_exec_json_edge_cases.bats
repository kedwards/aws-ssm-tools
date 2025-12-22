#!/usr/bin/env bats

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

# Mock all external dependencies
log_debug() { :; }
log_info() { :; }
log_warn() { :; }
log_error() { :; }
log_success() { :; }

ensure_aws_cli() { return 0; }
parse_common_flags() { return 0; }
aws_ssm_select_command() { eval "$1='uptime'"; return 0; }
choose_profile_and_region() { PROFILE="test"; REGION="us-east-1"; return 0; }
aws_auth_assume() { return 0; }
aws_expand_instances() { echo "i-abc123"; return 0; }
aws_get_all_running_instances() { INSTANCE_LIST=("web i-abc123"); }
menu_select_many() { eval "$2='web i-abc123'"; return 0; }

# Source the command
source ./lib/commands/ssm_exec.sh

@test "ssm_exec escapes unicode characters in JSON payload" {
  local captured_json="/tmp/bats-test-$$-unicode"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='echo "Hello 世界"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "Hello 世界"' ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes carriage returns in JSON payload" {
  local captured_json="/tmp/bats-test-$$-cr"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG=$'echo "Line 1\r\nLine 2"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = $'echo "Line 1\r\nLine 2"' ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes tabs in JSON payload" {
  local captured_json="/tmp/bats-test-$$-tab"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG=$'echo "col1\tcol2\tcol3"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = $'echo "col1\tcol2\tcol3"' ]
  rm -f "$captured_json"
}

@test "ssm_exec handles command with mixed quotes and escapes" {
  local captured_json="/tmp/bats-test-$$-mixed"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='echo "He said \"Hello\" and she said '\''Goodbye'\''"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "He said \"Hello\" and she said '\''Goodbye'\''"' ]
  rm -f "$captured_json"
}

@test "ssm_exec handles empty command edge case" {
  COMMAND_ARG=""
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec handles command with backticks" {
  local captured_json="/tmp/bats-test-$$-backtick"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='echo `hostname`'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo `hostname`' ]
  rm -f "$captured_json"
}

@test "ssm_exec handles command with percent signs" {
  local captured_json="/tmp/bats-test-$$-percent"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='echo "CPU: 100%"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "CPU: 100%"' ]
  rm -f "$captured_json"
}

@test "ssm_exec handles command with ampersands" {
  local captured_json="/tmp/bats-test-$$-ampersand"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='echo "Bangers & Mash"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "Bangers & Mash"' ]
  rm -f "$captured_json"
}

@test "ssm_exec handles command with angle brackets" {
  local captured_json="/tmp/bats-test-$$-brackets"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='echo "<html><body>Test</body></html>"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "<html><body>Test</body></html>"' ]
  rm -f "$captured_json"
}

@test "ssm_exec correctly structures JSON with multiple parameters" {
  local captured_json="/tmp/bats-test-$$-structure"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  
  # Verify complete JSON structure
  jq -e '.Parameters' "$captured_json" > /dev/null
  jq -e '.Parameters.commands' "$captured_json" > /dev/null
  jq -e '.Parameters.executionTimeout' "$captured_json" > /dev/null
  
  # Verify commands is an array with exactly 2 elements
  local cmd_count=$(jq '.Parameters.commands | length' "$captured_json")
  [ "$cmd_count" = "2" ]
  
  # Verify executionTimeout is an array with 1 element
  local timeout_count=$(jq '.Parameters.executionTimeout | length' "$captured_json")
  [ "$timeout_count" = "1" ]
  
  rm -f "$captured_json"
}

@test "ssm_exec handles very long commands" {
  local captured_json="/tmp/bats-test-$$-long"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  # Create a very long command (500+ characters)
  local long_cmd="find /var/log -name '*.log' -type f -mtime +30 -exec echo 'Found old log file: {}' \; | grep -v 'system' | grep -v 'auth' | sort | uniq | head -n 100 | tail -n 50 | awk '{print \$1, \$2, \$3}' | sed 's/foo/bar/g' | tr '[:upper:]' '[:lower:]' | xargs -I {} sh -c 'echo Processing: {}; cat {}; echo Done' | tee /tmp/output.log | wc -l"
  
  COMMAND_ARG="$long_cmd"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = "$long_cmd" ]
  rm -f "$captured_json"
}

@test "ssm_exec handles SQL-like commands with special chars" {
  local captured_json="/tmp/bats-test-$$-sql"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == file://* ]]; then
          cp "${arg#file://}" "$captured_json"
          break
        fi
      done
      echo "cmd-12345"
    elif [[ "$1" == "sts" ]]; then
      echo "123456789012"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      echo "Success"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG='psql -c "SELECT * FROM users WHERE name = '\''John'\'' AND age > 30;"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'psql -c "SELECT * FROM users WHERE name = '\''John'\'' AND age > 30;"' ]
  rm -f "$captured_json"
}
