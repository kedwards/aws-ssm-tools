#!/usr/bin/env bats
# shellcheck disable=SC2329,SC2030,SC2031

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

setup() {
  # Reset global flags
  CONFIG_MODE=false
  SHOW_HELP=false
  PROFILE=""
  REGION=""

  # AWS auth stubs
  aws_auth_assume(){ :; }

  # logging stubs
  log_debug(){ :; }
  log_info(){ :; }
  log_warn(){ :; }
  log_error(){ :; }

  # Core stubs
  ensure_aws_cli(){ :; }
  parse_common_flags(){ :; }
  choose_profile_and_region(){ :; }
  aws_sso_validate_or_login(){ :; }

  # menu dependency (REAL implementation)
  source ./lib/menu/index.sh
  source ./lib/core/flags.sh
  source ./lib/commands/ssm_connect.sh

  # aws/ec2 stub
  aws_ec2_select_instance() {
    echo "test-instance i-1234567890"
  }

  aws_get_all_running_instances() {
    INSTANCE_LIST=("test-instance i-1234567890")
  }

  # aws ssm stub
  aws_ssm_start_shell() {
    echo "SSM_SHELL $1"
  }
}

@test "ssm connect shell mode starts SSM shell" {
  export MENU_NON_INTERACTIVE=1
  export MENU_ASSUME_FIRST=1
  export CONFIG_MODE=false

  run ssm_connect

  assert_success
  assert_output --partial "SSM_SHELL i-1234567890"
}

@test "ssm connect --help does not require AWS" {
  # Restore real flag parsing for this test
  unset -f parse_common_flags
  source ./lib/core/flags.sh

  run ssm_connect --help

  assert_success
  assert_output --partial "Usage: ssm connect"
}


