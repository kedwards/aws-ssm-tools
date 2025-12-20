#!/usr/bin/env bats

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

# Mock all external dependencies
log_debug() { :; }
log_info() { :; }
log_warn() { :; }
log_error() { :; }
log_success() { :; }
echo() { command echo "$@"; }  # Keep echo for output
date() { command echo "2025-01-01T12:00:00+0000"; }

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

@test "ssm_exec polls for command completion" {
  local poll_file="/tmp/bats-poll-$$"
  echo "0" > "$poll_file"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local count=$(cat "$poll_file")
      count=$((count + 1))
      echo "$count" > "$poll_file"
      
      if [[ $count -le 2 ]]; then
        # First two polls: still running
        echo "InProgress"
      else
        # Third poll: success
        echo "Success"
      fi
    fi
    return 0
  }
  export poll_file
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  local final_count=$(cat "$poll_file" 2>/dev/null || echo "0")
  rm -f "$poll_file"
  
  assert_success
  # Should have polled multiple times
  [[ $final_count -ge 3 ]]
}

@test "ssm_exec sleeps between poll attempts" {
  local aws_log="/tmp/bats-aws-poll-$$"
  aws() {
    echo "$(date +%s) $*" >> "$aws_log"
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local count=$(grep -c "get-command-invocation" "$aws_log" 2>/dev/null || echo "0")
      if [[ $count -lt 2 ]]; then
        echo "InProgress"
      else
        echo "Success"
      fi
    fi
    return 0
  }
  sleep() {
    echo "sleep $1" >> "$aws_log"
  }
  export aws_log
  export -f aws
  export -f sleep
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  local sleep_calls=$(grep -c "^sleep" "$aws_log" 2>/dev/null || echo "0")
  rm -f "$aws_log"
  
  # Should have slept at least once
  [[ $sleep_calls -ge 1 ]]
}

@test "ssm_exec displays status during polling" {
  local status_file="/tmp/bats-status-$$"
  echo "0" > "$status_file"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local count=$(cat "$status_file")
      count=$((count + 1))
      echo "$count" > "$status_file"
      
      if [[ $count -eq 1 ]]; then
        echo "Pending"
      elif [[ $count -eq 2 ]]; then
        echo "InProgress"
      else
        echo "Success"
      fi
    fi
    return 0
  }
  export status_file
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  rm -f "$status_file"
  
  assert_success
  # Should show status updates
  assert_output --partial "i-abc123"
}

@test "ssm_exec polls multiple instances" {
  local aws_log="/tmp/bats-aws-multi-$$"
  aws() {
    echo "$*" >> "$aws_log"
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      # Always return success
      echo "Success"
    fi
    return 0
  }
  aws_expand_instances() {
    case "$1" in
      "web") echo "i-abc123" ;;
      "db") echo "i-def456" ;;
    esac
  }
  export aws_log
  export -f aws
  export -f aws_expand_instances
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="web,db"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  local aws_calls=$(cat "$aws_log" 2>/dev/null || echo "")
  rm -f "$aws_log"
  
  # Should poll both instances
  [[ "$aws_calls" =~ "i-abc123" ]]
  [[ "$aws_calls" =~ "i-def456" ]]
}

@test "ssm_exec stops polling when all instances complete" {
  local poll_file="/tmp/bats-poll-$$"
  echo "0" > "$poll_file"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local count=$(cat "$poll_file")
      count=$((count + 1))
      echo "$count" > "$poll_file"
      echo "Success"  # Immediately complete
    fi
    return 0
  }
  sleep() {
    # Should not sleep if all complete
    echo "ERROR: sleep called when all complete"
  }
  export poll_file
  export -f aws
  export -f sleep
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  local final_count=$(cat "$poll_file" 2>/dev/null || echo "0")
  rm -f "$poll_file"
  
  assert_success
  refute_output --partial "ERROR: sleep called"
  # Should poll at least once (and then fetch output)
  [[ $final_count -ge 1 ]]
}

@test "ssm_exec handles pending status" {
  local call_file="/tmp/bats-call-$$"
  echo "0" > "$call_file"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local num=$(cat "$call_file")
      num=$((num + 1))
      echo "$num" > "$call_file"
      
      case $num in
        1) echo "Pending" ;;
        2) echo "InProgress" ;;
        *) echo "Success" ;;
      esac
    fi
    return 0
  }
  export call_file
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  rm -f "$call_file"
  
  assert_success
  assert_output --partial "pending"
}

@test "ssm_exec handles delayed status" {
  local call_file="/tmp/bats-delayed-$$"
  echo "0" > "$call_file"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local num=$(cat "$call_file")
      num=$((num + 1))
      echo "$num" > "$call_file"
      
      case $num in
        1) echo "Delayed" ;;
        *) echo "Success" ;;
      esac
    fi
    return 0
  }
  export call_file
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  rm -f "$call_file"
  
  assert_success
  assert_output --partial "delayed"
}

@test "ssm_exec continues polling on failed status" {
  local call_file="/tmp/bats-failed-$$"
  echo "0" > "$call_file"
  
  aws() {
    if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
      echo "cmd-12345"
    elif [[ "$1" == "ssm" && "$2" == "get-command-invocation" ]]; then
      local num=$(cat "$call_file")
      num=$((num + 1))
      echo "$num" > "$call_file"
      
      case $num in
        1) echo "InProgress" ;;
        *) echo "Failed" ;;
      esac
    fi
    return 0
  }
  export call_file
  export -f aws
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-abc123"
  PROFILE="test"
  REGION="us-east-1"
  
  run ssm_exec
  
  rm -f "$call_file"
  
  assert_success
  assert_output --partial "failed"
}
