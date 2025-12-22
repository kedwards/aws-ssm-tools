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

  # isolate environment - unset from the current shell
  unset -v AWS_ACCESS_KEY_ID
  unset -v AWS_SECRET_ACCESS_KEY
  unset -v AWS_SESSION_TOKEN
  unset -v AWS_PROFILE
  unset -v AWS_REGION
  unset -v AWS_DEFAULT_REGION

  # flags defaults
  SHOW_HELP=false

  # load auth code
  source ./lib/core/aws_auth.sh
}

teardown() {
  unset -v AWS_ACCESS_KEY_ID
  unset -v AWS_SECRET_ACCESS_KEY
  unset -v AWS_SESSION_TOKEN
  unset -v AWS_PROFILE
  unset -v AWS_REGION
  unset -v AWS_DEFAULT_REGION
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

@test "aws_auth_assume fails when no credentials exist" {
  stub_sts_invalid

  run aws_auth_assume default us-west-2

  assert_failure
  assert_output --partial "No AWS credentials found"
}

@test "aws_auth_assume succeeds when credentials exist" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN
  export AWS_PROFILE=default
  export AWS_REGION=us-west-2

  stub_sts_valid

  run aws_auth_assume default us-west-2

  assert_success
}

@test "aws_auth_assume fails when profile mismatch" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN
  export AWS_PROFILE=prod
  export AWS_REGION=us-west-2

  stub_sts_valid

  run aws_auth_assume dev us-west-2

  assert_failure
  assert_output --partial "Currently authenticated with profile 'prod'"
  assert_output --partial "Requested profile 'dev'"
}

@test "aws_auth_assume fails when region mismatch" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN
  export AWS_PROFILE=default
  export AWS_REGION=us-east-1

  stub_sts_valid

  run aws_auth_assume default us-west-2

  assert_failure
  assert_output --partial "Currently authenticated with region 'us-east-1'"
  assert_output --partial "Requested region 'us-west-2'"
}

@test "aws_auth_assume succeeds with matching profile and region" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN
  export AWS_PROFILE=default
  export AWS_REGION=us-west-2

  stub_sts_valid

  run aws_auth_assume default us-west-2

  assert_success
}

@test "aws_auth_assume succeeds with valid credentials" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN
  export AWS_PROFILE=test-profile
  export AWS_REGION=us-west-2

  stub_sts_valid

  run aws_auth_assume test-profile us-west-2

  assert_success
}

@test "aws_auth_assume succeeds when AWS auth exists" {
  stub_sts_valid

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

@test "aws_auth_assume allows empty profile when authenticated" {
  export AWS_ACCESS_KEY_ID=AKIA_TEST
  export AWS_SECRET_ACCESS_KEY=SECRET
  export AWS_SESSION_TOKEN=TOKEN
  export AWS_PROFILE=any-profile
  export AWS_REGION=us-west-2

  stub_sts_valid

  run aws_auth_assume "" us-west-2

  assert_success
}
