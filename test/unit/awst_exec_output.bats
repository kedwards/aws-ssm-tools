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
awst_select_ssm_command() { eval "$1='uptime'"; return 0; }
choose_profile_and_region() { PROFILE="test"; REGION="us-east-1"; return 0; }
aws_auth_assume() { return 0; }
aws_expand_instances() { echo "i-abc123"; return 0; }
aws_get_all_running_instances() { INSTANCE_LIST=("web i-abc123"); }
menu_select_many() { eval "$2='web i-abc123'"; return 0; }

# Source the command
source ./lib/commands/awst_exec.sh

@test "awst_exec displays stdout from instance" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        echo "Hello from instance"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "Hello from instance"
}

@test "awst_exec displays stderr from instance" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardErrorContent" ]]; then
        echo "Error output"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "Error output"
}

@test "awst_exec shows instance ID in results header" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "ID: i-abc123"
}

@test "awst_exec shows status in results header" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "Status: Success"
}

@test "awst_exec labels stdout output" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        echo "output data"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "STDOUT"
}

@test "awst_exec labels stderr output" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardErrorContent" ]]; then
        echo "error data"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "STDERR"
}

@test "awst_exec shows message when no output" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      fi
      # No output
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "No output returned"
}

@test "awst_exec displays output from multiple instances" {
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
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
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
  export -f aws_expand_instances
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="web,db"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  assert_output --partial "Output from instance 1"
  assert_output --partial "Output from instance 2"
}

@test "awst_exec uses dividers between results" {
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      if [[ "$*" =~ "--query Status" ]]; then
        echo "Success"
      elif [[ "$*" =~ "StandardOutputContent" ]]; then
        echo "some output"
      fi
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  assert_success
  # Should have box drawing characters for dividers
  assert_output --partial "┌─"
  assert_output --partial "└─"
}

@test "awst_exec handles get-command-invocation failure gracefully" {
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
    elif [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "123456789012"
    fi
    return 0
  }
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run awst_exec
  
  # Should still succeed overall
  assert_success
}
