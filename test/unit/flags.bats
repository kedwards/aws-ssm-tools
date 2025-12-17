#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

setup() {
  # Remove any stubs from other test files
  unset -f parse_common_flags || true

  # Reset globals
  DRY_RUN=false
  CONFIG_MODE=false
  SHOW_HELP=false
  PROFILE=""
  REGION=""
  POSITIONAL=()

  source ./lib/core/flags.sh
}

teardown() {
  # Ensure no leakage to other test files
  DRY_RUN=false
  CONFIG_MODE=false
  SHOW_HELP=false
  PROFILE=""
  REGION=""
  POSITIONAL=()
}

@test "parse_common_flags sets DRY_RUN" {
  parse_common_flags --dry-run
  [ "$DRY_RUN" = true ]
}

@test "parse_common_flags sets CONFIG_MODE" {
  parse_common_flags --config
  [ "$CONFIG_MODE" = true ]
}

@test "parse_common_flags collects positional args" {
  parse_common_flags foo bar
  [ "${POSITIONAL[0]}" = "foo" ]
  [ "${POSITIONAL[1]}" = "bar" ]
}

@test "parse_common_flags handles mixed flags and args" {
  parse_common_flags --dry-run -p test foo bar

  [ "$DRY_RUN" = true ]
  [ "$PROFILE" = "test" ]
  [ "${POSITIONAL[0]}" = "foo" ]
  [ "${POSITIONAL[1]}" = "bar" ]
}
