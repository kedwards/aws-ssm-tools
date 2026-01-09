#!/usr/bin/env bats

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

# Stub logging functions
log_debug()   { :; }
log_info()    { echo "[INFO] $*"; }
log_warn()    { echo "[WARN] $*"; }
log_error()   { echo "[ERROR] $*" >&2; }
log_success() { echo "[SUCCESS] $*"; }

setup() {
  # Create a temporary directory for fake installation
  export FAKE_HOME="$(mktemp -d)"
  export HOME="$FAKE_HOME"
  export INSTALL_DIR="${HOME}/.local/share/aws-ssm-tools"
  
  # Source the update command
  source ./lib/commands/ssm_update.sh
}

teardown() {
  # Clean up fake home
  rm -rf "$FAKE_HOME"
}

@test "ssm_update shows help with --help" {
  run ssm_update --help
  assert_success
  assert_output --partial "Usage: ssm update"
}

@test "ssm_update shows help with -h" {
  run ssm_update -h
  assert_success
  assert_output --partial "Usage: ssm update"
}

@test "ssm_update fails when not installed" {
  run ssm_update
  assert_failure
  assert_output --partial "not installed"
}

@test "ssm_update shows current version when installed" {
  # Create fake installation
  mkdir -p "$INSTALL_DIR"
  echo "1.3.1" > "$INSTALL_DIR/VERSION"
  
  # Stub curl to fail so it doesn't proceed
  curl() { return 1; }
  
  run ssm_update
  
  assert_failure
  assert_output --partial "Current version: 1.3.1"
}

@test "ssm_update usage mentions specific version example" {
  run ssm_update --help
  assert_success
  assert_output --partial "vX.Y.Z"
}

@test "ssm_update usage mentions main branch option" {
  run ssm_update --help
  assert_success
  assert_output --partial "main"
}

@test "ssm_update usage mentions dev branch option" {
  run ssm_update --help
  assert_success
  assert_output --partial "dev"
}
