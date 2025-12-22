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

@test "ssm_exec escapes double quotes in JSON payload" {
  local captured_json="/tmp/bats-test-$$-1"
  
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
  
  COMMAND_ARG='echo "Hello World"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "Hello World"' ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes single quotes in JSON payload" {
  local captured_json="/tmp/bats-test-$$-2"
  
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
  
  COMMAND_ARG="echo 'Hello World'"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = "echo 'Hello World'" ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes backslashes in JSON payload" {
  local captured_json="/tmp/bats-test-$$-3"
  
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
  
  COMMAND_ARG='echo "Path: C:\Users\Test"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "Path: C:\Users\Test"' ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes newlines in JSON payload" {
  local captured_json="/tmp/bats-test-$$-4"
  
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
  
  COMMAND_ARG=$'echo "Line 1\nLine 2"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = $'echo "Line 1\nLine 2"' ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes dollar signs in JSON payload" {
  local captured_json="/tmp/bats-test-$$-5"
  
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
  
  COMMAND_ARG='echo "Price: $100"'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'echo "Price: $100"' ]
  rm -f "$captured_json"
}

@test "ssm_exec formats simple command into JSON payload" {
  local captured_json="/tmp/bats-test-$$-6"
  
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
  
  # Verify JSON structure
  jq -e '.Parameters' "$captured_json" > /dev/null
  jq -e '.Parameters.commands' "$captured_json" > /dev/null
  jq -e '.Parameters.executionTimeout' "$captured_json" > /dev/null
  
  # Verify shebang is first command
  local shebang=$(jq -r '.Parameters.commands[0]' "$captured_json")
  [ "$shebang" = "#!/bin/bash" ]
  
  # Verify actual command is second
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = "uptime" ]
  
  # Verify timeout
  local timeout=$(jq -r '.Parameters.executionTimeout[0]' "$captured_json")
  [ "$timeout" = "600" ]
  
  rm -f "$captured_json"
}

@test "ssm_exec formats command with arguments into JSON payload" {
  local captured_json="/tmp/bats-test-$$-7"
  
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
  
  COMMAND_ARG="ls -la /var/log"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = "ls -la /var/log" ]
  rm -f "$captured_json"
}

@test "ssm_exec formats command with pipes into JSON payload" {
  local captured_json="/tmp/bats-test-$$-8"
  
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
  
  COMMAND_ARG="ps aux | grep nginx"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = "ps aux | grep nginx" ]
  rm -f "$captured_json"
}

@test "ssm_exec escapes complex command with multiple special characters" {
  local captured_json="/tmp/bats-test-$$-9"
  
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
  
  COMMAND_ARG='grep -r "ERROR: $msg" /var/log/*.log | tail -n 10'
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  [ -f "$captured_json" ]
  local cmd=$(jq -r '.Parameters.commands[1]' "$captured_json")
  [ "$cmd" = 'grep -r "ERROR: $msg" /var/log/*.log | tail -n 10' ]
  rm -f "$captured_json"
}
