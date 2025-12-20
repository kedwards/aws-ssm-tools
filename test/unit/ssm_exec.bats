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
aws_ssm_select_command() { return 0; }
choose_profile_and_region() { return 0; }
aws_auth_assume() { return 0; }
aws_expand_instances() { return 0; }
aws_get_all_running_instances() { INSTANCE_LIST=(); }
menu_select_many() { return 0; }
aws() {
  # Mock aws CLI
  if [[ "$1" == "ssm" && "$2" == "send-command" ]]; then
    echo "cmd-12345"
  fi
  return 0
}

setup() {
  # Unset AWS environment variables to ensure tests are isolated
  unset AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  # Create mock .aws directory for region auto-detection tests
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/.aws"
  touch "$HOME/.aws/config"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# Source the command
source ./lib/commands/ssm_exec.sh

@test "ssm_exec_usage displays help text" {
  run ssm_exec_usage
  
  assert_success
  assert_output --partial "Usage: ssm exec [OPTIONS]"
  assert_output --partial "Run a shell command via AWS SSM"
  assert_output --partial "-c <command>"
  assert_output --partial "-i <instances>"
  assert_output --partial "Examples:"
}

@test "ssm_exec shows help with -h flag" {
  SHOW_HELP=true
  
  run ssm_exec
  
  assert_success
  assert_output --partial "Usage: ssm exec"
}

@test "ssm_exec shows help with --help flag" {
  SHOW_HELP=true
  
  run ssm_exec --help
  
  assert_success
  assert_output --partial "Usage: ssm exec"
}

@test "ssm_exec calls ensure_aws_cli" {
  ensure_aws_cli() {
    echo "ensure_aws_cli_called"
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_output --partial "ensure_aws_cli_called"
}

@test "ssm_exec fails if ensure_aws_cli fails" {
  ensure_aws_cli() { return 1; }
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec calls parse_common_flags with all arguments" {
  parse_common_flags() {
    echo "parse_common_flags: $*"
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec -c "uptime" -i "i-12345"
  
  assert_output --partial "parse_common_flags: -c uptime -i i-12345"
}

@test "ssm_exec fails if parse_common_flags fails" {
  parse_common_flags() { return 1; }
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec prompts for command if COMMAND_ARG is empty" {
  aws_ssm_select_command() {
    eval "$1='uptime'"
    echo "select_command_called"
    return 0
  }
  COMMAND_ARG=""
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_output --partial "select_command_called"
}

@test "ssm_exec fails if command selection fails" {
  aws_ssm_select_command() { return 1; }
  COMMAND_ARG=""
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec calls aws_auth_assume" {
  aws_auth_assume() {
    echo "auth_assume: $1 $2"
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_output --partial "auth_assume:"
}

@test "ssm_exec fails if aws_auth_assume fails" {
  aws_auth_assume() { return 1; }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec validates command is not empty after selection" {
  aws_ssm_select_command() {
    eval "$1=''"
    return 0
  }
  COMMAND_ARG=""
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec uses COMMAND_ARG if provided" {
  aws_ssm_select_command() {
    echo "should_not_be_called"
    return 1
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="i-12345"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  refute_output --partial "should_not_be_called"
}


# Instance expansion and selection tests

@test "ssm_exec expands single instance from INSTANCES_ARG" {
  aws_expand_instances() {
    echo "i-abc123"
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="Report"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
}

@test "ssm_exec expands multiple comma-separated instances" {
  aws_expand_instances() {
    case "$1" in
      "Report") echo "i-abc123" ;;
      "Singleton") echo "i-def456" ;;
    esac
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="Report,Singleton"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
}

@test "ssm_exec trims whitespace from instance names" {
  aws_expand_instances() {
    case "$1" in
      "Report") echo "i-report" ;;
      "Singleton") echo "i-singleton" ;;
    esac
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG=" Report , Singleton "
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  # Should succeed with both trimmed instances
  assert_success
}

@test "ssm_exec warns when no running instance found for name" {
  aws_expand_instances() {
    return 0  # No output means no instances
  }
  log_warn() {
    echo "log_warn: $*"
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="NonExistent"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_output --partial "log_warn: No running instance found matching: NonExistent"
  assert_failure
}

@test "ssm_exec prompts for instances if INSTANCES_ARG is empty" {
  aws_get_all_running_instances() {
    INSTANCE_LIST=("web-server i-abc123" "db-server i-def456")
  }
  menu_select_many() {
    echo "menu_select_many_called"
    printf '%s' "web-server i-abc123"
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG=""
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_output --partial "menu_select_many_called"
}

@test "ssm_exec fails if no running instances found for interactive" {
  aws_get_all_running_instances() {
    INSTANCE_LIST=()
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG=""
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec fails if user cancels instance selection" {
  aws_get_all_running_instances() {
    INSTANCE_LIST=("web-server i-abc123")
  }
  menu_select_many() {
    return 130  # User cancelled
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG=""
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
  [[ $status -eq 130 ]]
}

@test "ssm_exec fails if no instances selected" {
  aws_get_all_running_instances() {
    INSTANCE_LIST=("web-server i-abc123")
  }
  menu_select_many() {
    printf '%s' ""
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG=""
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec extracts instance IDs from menu selections" {
  aws_get_all_running_instances() {
    INSTANCE_LIST=("web-server i-abc123" "db-server i-def456")
  }
  menu_select_many() {
    # Simulate multi-line selection (output to stdout)
    printf '%s\n%s' "web-server i-abc123" "db-server i-def456"
    return 0
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG=""
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
}

@test "ssm_exec fails if no valid instances found after expansion" {
  aws_expand_instances() {
    return 0  # No output
  }
  COMMAND_ARG="uptime"
  INSTANCES_ARG="BadName1,BadName2"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_failure
}

@test "ssm_exec correctly parses and expands comma-separated instance names" {
  # Create temp file to track expansion calls
  EXPAND_LOG="$(mktemp)"
  
  aws_expand_instances() {
    echo "$1" >> "$EXPAND_LOG"
    case "$1" in
      "web-server") echo "i-web123" ;;
      "db-server") echo "i-db456" ;;
      "cache-server") echo "i-cache789" ;;
    esac
    return 0
  }
  
  COMMAND_ARG="uptime"
  INSTANCES_ARG="web-server,db-server,cache-server"
  PROFILE="test-profile"
  REGION="us-east-1"
  
  run ssm_exec
  
  assert_success
  
  # Verify all three instance names were parsed and expanded
  expanded=$(cat "$EXPAND_LOG")
  [[ "$expanded" =~ "web-server" ]]
  [[ "$expanded" =~ "db-server" ]]
  [[ "$expanded" =~ "cache-server" ]]
  
  # Verify we have exactly 3 expansion calls
  expand_count=$(wc -l < "$EXPAND_LOG")
  [ "$expand_count" -eq 3 ]
  
  rm -f "$EXPAND_LOG"
}
