#!/usr/bin/env bats
# shellcheck disable=SC2329,SC2030,SC2031

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

stub_assume_missing() {
  command() {
    if [[ "$1" == "-v" && "$2" == "assume" ]]; then
      return 1
    fi
    builtin command "$@"
  }
}

stub_sts_valid() {
  aws() {
    [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]
  }
}

stub_sts_invalid() {
  aws() {
    return 1
  }
}

setup() {

  assume() {
    echo "ERROR: assume should not be called in this test" >&2
    return 99
  }

  # logging stubs
  log_debug(){ :; }
  log_info(){ :; }
  log_warn(){ :; }
  log_error(){ echo "$*" >&2; }

  # isolate environment
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  unset AWS_PROFILE
  unset AWS_REGION

  # flags defaults
  SHOW_HELP=false
  DRY_RUN=false

  # load auth code
  source ./lib/core/aws_auth.sh
}

teardown() {
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
}

@test "aws_auth_is_valid returns false when no credentials exist" {
  run aws_auth_is_valid
  assert_failure
}

@test "aws_auth_is_valid returns true when credentials exist" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN

  run aws_auth_is_valid
  assert_success
}

@test "aws_auth_assume fails fast when assume command is missing" {
  assume() { return 127; }

  run aws_auth_assume default us-west-2

  assert_failure
  assert_output --partial "assume"
}

@test "aws_auth_assume invokes assume when not authenticated" {
  non_interactive_mode() { return 1; }

  assume() {
    echo "ASSUME CALLED: $*"
    export AWS_ACCESS_KEY_ID=AKIA_TEST
    export AWS_SECRET_ACCESS_KEY=SECRET
    export AWS_SESSION_TOKEN=TOKEN
    return 0
  }

  run aws_auth_assume test us-west-2

  assert_success
  assert_output --partial "ASSUME CALLED: test -r us-west-2"
}

@test "aws_auth_assume fails if assume returns non-zero" {
  non_interactive_mode() { return 1; }


  assume() {
    echo "ASSUME FAILED"
    return 1
  }

  run aws_auth_assume default us-west-2

  assert_failure
  assert_output --partial "Failed"
}

@test "aws_auth_assume fails if assume does not export credentials" {
  non_interactive_mode() { return 1; }
  assume() {
    echo "ASSUME CALLED"
    return 0
  }

  run aws_auth_assume default us-west-2

  assert_failure
  assert_output --partial "did not produce valid AWS credentials"
}

@test "aws_auth_assume skips assume when already authenticated" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN

  stub_sts_valid

  assume() {
    echo "ERROR: assume should not be called"
    return 99
  }

  run aws_auth_assume default us-west-2

  assert_success
  refute_output --partial "ERROR"
}

@test "aws_auth_assume exports AWS_PROFILE and AWS_REGION on success" {
  non_interactive_mode() { return 1; }

  assume() {
    export AWS_ACCESS_KEY_ID=AKIA_TEST
    export AWS_SECRET_ACCESS_KEY=SECRET
    export AWS_SESSION_TOKEN=TOKEN
    return 0
  }

  stub_sts_invalid

  run aws_auth_assume test-profile us-west-2

  assert_success
}

@test "aws_auth_assume succeeds when AWS auth exists" {
  stub_sts_valid

  run aws_auth_assume default us-west-2
  assert_success
}

@test "aws_auth_assume fails fast when no AWS auth exists" {
  non_interactive_mode() { return 1; }

  unset -f assume

  stub_assume_missing
  stub_sts_invalid

  run aws_auth_assume default us-west-2

  assert_failure
  assert_output --partial "'assume' command"
}

@test "aws_auth_assume is skipped during dry-run" {
  DRY_RUN=true

  aws() {
    echo "SHOULD NOT RUN"
    return 1
  }

  run aws_auth_assume default us-west-2
  assert_success
}

@test "aws_auth_assume is skipped during help" {
  SHOW_HELP=true

  aws() {
    echo "SHOULD NOT RUN"
    return 1
  }

  run aws_auth_assume default us-west-2
  assert_success
}

@test "aws_auth_assume calls granted with profile and region" {
  non_interactive_mode() { return 1; }

  assume() {
    echo "ASSUME CALLED: $*"
    export AWS_ACCESS_KEY_ID=AKIA_TEST
    export AWS_SECRET_ACCESS_KEY=SECRET
    export AWS_SESSION_TOKEN=TOKEN
    return 0
  }

  stub_sts_invalid

  run aws_auth_assume test us-west-2

  assert_success
  assert_output --partial "ASSUME CALLED: test -r us-west-2"
}
