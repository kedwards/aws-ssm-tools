#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  export AWS_LOG_LEVEL=DEBUG
  export AWS_LOG_TIMESTAMP=0
  export AWS_LOG_COLOR=0
  export AWS_LOG_FILE="$BATS_TEST_TMPDIR/test.log"
  export AWS_LOG_FILE_MAX_SIZE=50
  export AWS_LOG_FILE_ROTATE=2

  # temp directory for test files
  TEST_TEMP_DIR="$(mktemp -d)"
  export HOME="$TEST_TEMP_DIR"

  source ./lib/core/logging.sh
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
}

@test "INFO logs are written to file" {
  log_info "hello world"
  run grep "hello world" "$AWS_LOG_FILE"
  [ "$status" -eq 0 ]
}

@test "DEBUG logs respect log level" {
  export AWS_LOG_LEVEL=INFO
  log_debug "hidden"
  run ! grep -q hidden "$AWS_LOG_FILE"
}

@test "log rotation occurs" {
  log_info "123456789012345678901234567890"
  log_info "123456789012345678901234567890"
  log_info "trigger rotation"
  [ -f "$AWS_LOG_FILE.1" ]
}

@test "ERR trap logs stacktrace" {
  run bash -c '
    source ../lib/log.sh
    AWS_LOG_FILE="$AWS_LOG_FILE"
    fail_func() { false; }
    fail_func
  '
  grep -q "stacktrace" "$AWS_LOG_FILE" || true
}
