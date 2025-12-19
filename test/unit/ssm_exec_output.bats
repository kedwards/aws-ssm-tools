#!/usr/bin/env bats

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

# Mock all external dependencies
log_debug() { :; }
log_info() { :; }
log_warn() { :; }
log_error() { :; }
log_success() { :; }
echo() { command echo "$@"; }
date() { command echo "2025-01-01T12:00:00+0000"; }

ensure_aws_cli() { return 0; }
parse_common_flags() { return 0; }
aws_ssm_select_command() { eval "$1='uptime'"; return 0; }
choose_profile_and_region() { PROFILE="test"; REGION="us-east-1"; return 0; }
aws_assume_profile() { return 0; }
aws_expand_instances() { echo "i-abc123"; return 0; }
aws_get_all_running_instances() { INSTANCE_LIST=("web i-abc123"); }
menu_select_many() { eval "$2='web i-abc123'"; return 0; }

# Source the command
source ./lib/commands/ssm_exec.sh

@test "ssm_exec displays stdout from instance" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        echo "Hello from instance"
      fi
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
  assert_output --partial "Hello from instance"
}

@test "ssm_exec displays stderr from instance" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardErrorContent" ]]; then
        echo "Error output"
      fi
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
  assert_output --partial "Error output"
}

@test "ssm_exec shows instance ID in results header" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      fi
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
  assert_output --partial "i-abc123"
  assert_output --partial "RESULTS FROM"
}

@test "ssm_exec shows status in results header" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      fi
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
  assert_output --partial "STATUS Success"
}

@test "ssm_exec labels stdout output" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        echo "output data"
      fi
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
  assert_output --partial "STDOUT:"
}

@test "ssm_exec labels stderr output" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardErrorContent" ]]; then
        echo "error data"
      fi
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
  assert_output --partial "STDERR:"
}

@test "ssm_exec shows message when no output" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      fi
      # No output
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
  assert_output --partial "NO OUTPUT"
}

@test "ssm_exec displays output from multiple instances" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        if [[ "$*" =~ "i-abc123" ]]; then
          echo "Output from instance 1"
        elif [[ "$*" =~ "i-def456" ]]; then
          echo "Output from instance 2"
        fi
      fi
    fi
    return 0
  }
  aws_expand_instances() {
    case "$1" in
      "web") echo "i-abc123" ;;
      "db") echo "i-def456" ;;
    esac
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="web;db"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  assert_output --partial "Output from instance 1"
  assert_output --partial "Output from instance 2"
}

@test "ssm_exec uses dividers between results" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        echo "some output"
      fi
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
  # Should have dividers
  assert_output --partial "----"
}

@test "ssm_exec handles get-command-invocation failure gracefully" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      else
        # Fail on output queries
        return 1
      fi
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  # Should still succeed overall
  assert_success
}
