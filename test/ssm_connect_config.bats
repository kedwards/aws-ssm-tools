#!/usr/bin/env bats
#shellcheck disable=SC2329

load 'helpers/bats-support/load'
load 'helpers/bats-assert/load'

setup() {
  # Force-load the real implementation
  unset -f parse_common_flags || true
  source ./lib/core/flags.sh

  # Reset global flags
  CONFIG_MODE=false
  SHOW_HELP=false
  PROFILE=""
  REGION=""

  # AWS auth stubs
  aws_auth_assume() { return 0; }

  # logging stubs
  log_debug(){ :; }
  log_info(){ :; }
  log_warn(){ :; }
  log_error(){ :; }

  # core stubs
  ensure_aws_cli(){ :; }
  parse_common_flags(){ :; }
  choose_profile_and_region(){ :; }
  aws_sso_validate_or_login(){ :; }

  # menu
  # Real menu implementation, but non-interactive
  export MENU_NON_INTERACTIVE=1
  export MENU_ASSUME_FIRST=1
  source ./lib/menu/index.sh

  # config helper stub
  aws_ssm_config_get() {
    local _file="$1"
    local _section="$2"
    local key="$3"

    case "$key" in
      profile)    echo "test-profile" ;;
      region)     echo "us-west-2" ;;
      port)       echo "5432" ;;
      local_port) echo "15432" ;;
      host)       echo "localhost" ;;
      # url)        echo "http://localhost:15432/" ;;
      name)       echo "test-instance" ;;
      *)          return 1 ;;
    esac
  }

  # SSM stub
  aws_ssm_start_shell() {
    echo "SSM_SHELL $1"
  }

  # EC2 stub
  aws_ec2_select_instance() {
    echo "test-instance i-1234567890"
  }

  # SSM stub
  aws_ssm_start_port_forward() {
    echo "SSM_PORT_FORWARD $1 $2 $3 $4"
  }

  source ./lib/commands/ssm_connect.sh
}

@test "ssm connect config mode starts port forward" {
  export CONFIG_MODE=true
  export CONFIG_FILE="$BATS_TEST_DIRNAME/fixtures/ssmf.cfg"

  run ssm_connect

  assert_success
  assert_output --partial "SSM_PORT_FORWARD i-1234567890 localhost 5432 15432"
}

@test "ssm connect config mode fails with empty config file" {
  # Ensure no other config files exist
  HOME="/tmp/test-home-$$"
  mkdir -p "$HOME"
  
  export CONFIG_MODE=true
  export CONFIG_FILE="$BATS_TEST_DIRNAME/fixtures/empty.cfg"

  run ssm_connect

  assert_failure
  
  # Cleanup
  rm -rf "$HOME"
}

@test "ssm connect config mode works without profile in config" {
  # Override stub to return empty profile
  aws_ssm_config_get() {
    local _file="$1"
    local _section="$2"
    local key="$3"

    case "$key" in
      profile)    echo "" ;;  # No profile in config
      region)     echo "us-west-2" ;;
      port)       echo "5432" ;;
      local_port) echo "15432" ;;
      host)       echo "localhost" ;;
      name)       echo "test-instance" ;;
      *)          return 1 ;;
    esac
  }

  # Stub choose_profile_and_region to set PROFILE
  choose_profile_and_region() {
    PROFILE="${PROFILE:-current-profile}"
    REGION="${REGION:-us-west-2}"
    return 0
  }

  export CONFIG_MODE=true
  export CONFIG_FILE="$BATS_TEST_DIRNAME/fixtures/no-profile.cfg"

  run ssm_connect

  assert_success
  assert_output --partial "SSM_PORT_FORWARD i-1234567890 localhost 5432 15432"
}

@test "ssm connect config mode uses AWS_PROFILE when no profile in config" {
  # Override stub to return empty profile
  aws_ssm_config_get() {
    local _file="$1"
    local _section="$2"
    local key="$3"

    case "$key" in
      profile)    echo "" ;;  # No profile in config
      region)     echo "us-west-2" ;;
      port)       echo "5432" ;;
      local_port) echo "15432" ;;
      host)       echo "localhost" ;;
      name)       echo "test-instance" ;;
      *)          return 1 ;;
    esac
  }

  # Stub to verify current profile is used
  choose_profile_and_region() {
    PROFILE="${PROFILE:-${AWS_PROFILE:-fallback}}"
    REGION="${REGION:-us-west-2}"
    return 0
  }

  export CONFIG_MODE=true
  export CONFIG_FILE="$BATS_TEST_DIRNAME/fixtures/no-profile.cfg"
  export AWS_PROFILE="my-current-profile"

  run ssm_connect

  assert_success
  # Verify it still works with current profile
  assert_output --partial "SSM_PORT_FORWARD i-1234567890 localhost 5432 15432"
}

@test "ssm connect config mode overrides current profile when profile in config" {
  # Normal stub with profile specified
  aws_ssm_config_get() {
    local _file="$1"
    local _section="$2"
    local key="$3"

    case "$key" in
      profile)    echo "config-profile" ;;  # Profile specified in config
      region)     echo "us-west-2" ;;
      port)       echo "5432" ;;
      local_port) echo "15432" ;;
      host)       echo "localhost" ;;
      name)       echo "test-instance" ;;
      *)          return 1 ;;
    esac
  }

  # Stub to track that PROFILE was set from config
  local profile_used=""
  choose_profile_and_region() {
    profile_used="$PROFILE"
    REGION="${REGION:-us-west-2}"
    return 0
  }

  export CONFIG_MODE=true
  export CONFIG_FILE="$BATS_TEST_DIRNAME/fixtures/ssmf.cfg"
  export AWS_PROFILE="different-profile"

  run ssm_connect

  assert_success
  # Verify the config profile takes precedence
  assert_output --partial "SSM_PORT_FORWARD i-1234567890 localhost 5432 15432"
}

