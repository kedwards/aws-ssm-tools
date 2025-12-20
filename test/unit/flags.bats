#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

setup() {
  # Remove any stubs from other test files
  unset -f parse_common_flags || true

  # Reset globals
  CONFIG_MODE=false
  SHOW_HELP=false
  PROFILE=""
  REGION=""
  COMMAND_ARG=""
  INSTANCES_ARG=""
  POSITIONAL=()

  source ./lib/core/flags.sh
}

teardown() {
  # Ensure no leakage to other test files
  CONFIG_MODE=false
  SHOW_HELP=false
  PROFILE=""
  REGION=""
  COMMAND_ARG=""
  INSTANCES_ARG=""
  POSITIONAL=()
}

@test "parse_common_flags sets CONFIG_MODE with --config" {
  parse_common_flags --config
  [ "$CONFIG_MODE" = true ]
}

@test "parse_common_flags collects positional args" {
  parse_common_flags foo bar
  [ "${POSITIONAL[0]}" = "foo" ]
  [ "${POSITIONAL[1]}" = "bar" ]
}

@test "parse_common_flags handles mixed flags and args" {
  parse_common_flags -p test foo bar

  [ "$PROFILE" = "test" ]
  [ "${POSITIONAL[0]}" = "foo" ]
  [ "${POSITIONAL[1]}" = "bar" ]
}

@test "parse_common_flags sets COMMAND_ARG with -c" {
  parse_common_flags -c "df -h"
  [ "$COMMAND_ARG" = "df -h" ]
}

@test "parse_common_flags sets COMMAND_ARG with --command" {
  parse_common_flags --command "uptime"
  [ "$COMMAND_ARG" = "uptime" ]
}

@test "parse_common_flags sets INSTANCES_ARG with -i" {
  parse_common_flags -i "instance1;instance2"
  [ "$INSTANCES_ARG" = "instance1;instance2" ]
}

@test "parse_common_flags sets INSTANCES_ARG with --instances" {
  parse_common_flags --instances "web-server"
  [ "$INSTANCES_ARG" = "web-server" ]
}

@test "parse_common_flags handles command with spaces" {
  parse_common_flags -c "ls -la /var/log"
  [ "$COMMAND_ARG" = "ls -la /var/log" ]
}

@test "parse_common_flags handles both command and instances" {
  parse_common_flags -c "uptime" -i "server1;server2"
  [ "$COMMAND_ARG" = "uptime" ]
  [ "$INSTANCES_ARG" = "server1;server2" ]
}

@test "parse_common_flags with -c and --config sets both" {
  parse_common_flags -c uptime --config
  [ "$COMMAND_ARG" = "uptime" ]
  [ "$CONFIG_MODE" = true ]
}

@test "parse_common_flags preserves existing behavior for --config alone" {
  parse_common_flags --config
  [ "$CONFIG_MODE" = true ]
  [ -z "$COMMAND_ARG" ]
}
