#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWST_EC2_DISABLE_LIVE_CALLS=1
export AWST_AUTH_DISABLE_ASSUME=1

setup() {
  # Stub logging
  log_debug() { :; }
  log_info() { :; }
  log_warn() { :; }
  log_error() { :; }
  export -f log_debug log_info log_warn log_error
}

# main dispatch tests

@test "bin/awst shows help with --help" {
  run ./bin/awst --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst" ]]
  [[ "$output" =~ "Commands:" ]]
  [[ "$output" =~ "connect" ]]
  [[ "$output" =~ "exec" ]]
  [[ "$output" =~ "run" ]]
  [[ "$output" =~ "creds" ]]
  [[ "$output" =~ "list" ]]
  [[ "$output" =~ "kill" ]]
}

@test "bin/awst shows help with -h" {
  run ./bin/awst -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst" ]]
}

@test "bin/awst with no command shows help and exits with error" {
  run ./bin/awst
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage: awst" ]]
}

@test "bin/awst list runs successfully" {
  run ./bin/awst list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Active SSM sessions" ]]
}

@test "bin/awst shows error for unknown command" {
  run ./bin/awst unknown-cmd
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown command" ]]
}

@test "bin/awst list --help works" {
  run ./bin/awst list --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst list" ]]
}

@test "bin/awst kill --help works" {
  run ./bin/awst kill --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst kill" ]]
}

@test "bin/awst kill runs successfully" {
  run ./bin/awst kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No active SSM sessions found" ]]
}

@test "bin/awst exec --help works" {
  run ./bin/awst exec --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst exec" ]]
  [[ "$output" =~ "Run a shell command via AWS SSM" ]]
}

@test "bin/awst login returns unknown command" {
  run ./bin/awst login
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown command" ]]
}

@test "bin/awst run --help works" {
  run ./bin/awst run --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst run" ]]
  [[ "$output" =~ "Run a command or script" ]]
}

@test "bin/awst creds shows usage" {
  run ./bin/awst creds
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst creds" ]]
  [[ "$output" =~ "store" ]]
  [[ "$output" =~ "use" ]]
}
