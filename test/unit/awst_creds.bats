#!/usr/bin/env bats
# shellcheck disable=SC2329,SC2030,SC2031

export MENU_NON_INTERACTIVE=1
export AWST_EC2_DISABLE_LIVE_CALLS=1
export AWST_AUTH_DISABLE_ASSUME=1

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

# Stub logging
log_debug()   { :; }
log_info()    { :; }
log_warn()    { :; }
log_error()   { echo "$*" >&2; }
log_success() { echo "$*"; }

setup() {
  source ./lib/commands/awst_creds.sh
}

@test "awst_creds shows usage with no arguments" {
  run awst_creds

  assert_success
  assert_output --partial "Usage: awst creds <store|use>"
  assert_output --partial "store <env>"
  assert_output --partial "use"
}

@test "awst_creds shows usage with unknown subcommand" {
  run awst_creds unknown

  assert_success
  assert_output --partial "Usage: awst creds <store|use>"
}

@test "awst_creds store shows help with no env" {
  run awst_creds store

  assert_success
  assert_output --partial "Usage: awst creds store <env>"
  assert_output --partial "Requires: assume (Granted)"
}

@test "awst_creds store shows help with -h" {
  run awst_creds store -h

  assert_success
  assert_output --partial "Usage: awst creds store <env>"
}

@test "awst_creds store shows help with --help" {
  run awst_creds store --help

  assert_success
  assert_output --partial "Usage: awst creds store <env>"
}

@test "awst_creds store fails when assume not in PATH" {
  export AWST_AUTH_DISABLE_ASSUME=0

  # Override command to simulate assume not found
  command() {
    if [[ "$1" == "-v" && "$2" == "assume" ]]; then
      return 1
    fi
    builtin command "$@"
  }

  run awst_creds store myenv

  assert_failure
  assert_output --partial "'assume' (Granted) not found in PATH"
}

@test "awst_creds store skips when AWST_AUTH_DISABLE_ASSUME is set" {
  export AWST_AUTH_DISABLE_ASSUME=1

  # Stub assume to verify it's not called
  assume() {
    echo "SHOULD_NOT_RUN"
    return 99
  }

  command() {
    if [[ "$1" == "-v" && "$2" == "assume" ]]; then
      return 0
    fi
    builtin command "$@"
  }

  run awst_creds store myenv

  assert_success
  refute_output --partial "SHOULD_NOT_RUN"
}

@test "awst_creds use outputs export with stored vars" {
  export AK="AKIATEST123"
  export SK="SECRET456"
  export ST="TOKEN789"

  run awst_creds use

  assert_success
  assert_output --partial "export AWS_ACCESS_KEY_ID=\"AKIATEST123\""
  assert_output --partial "AWS_SECRET_ACCESS_KEY=\"SECRET456\""
  assert_output --partial "AWS_SESSION_TOKEN=\"TOKEN789\""
}

@test "awst_creds use outputs empty values when no stored vars" {
  unset AK SK ST

  run awst_creds use

  assert_success
  assert_output --partial 'AWS_ACCESS_KEY_ID=""'
  assert_output --partial 'AWS_SECRET_ACCESS_KEY=""'
  assert_output --partial 'AWS_SESSION_TOKEN=""'
}

@test "awst_creds dispatches store subcommand" {
  # Stub awst_creds_store to verify dispatch
  awst_creds_store() {
    echo "STORE_CALLED: $*"
  }

  run awst_creds store myenv

  assert_success
  assert_output --partial "STORE_CALLED: myenv"
}

@test "awst_creds dispatches use subcommand" {
  # Stub awst_creds_use to verify dispatch
  awst_creds_use() {
    echo "USE_CALLED"
  }

  run awst_creds use

  assert_success
  assert_output --partial "USE_CALLED"
}
