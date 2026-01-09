#!/usr/bin/env bats

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

# Stub logging functions
log_debug()   { :; }
log_info()    { :; }
log_warn()    { :; }
log_error()   { :; }

# Source function
setup() {
  source ./lib/menu/index.sh
}

@test "fails when no items are provided" {
  run menu_select_one "Pick" "Header" result
  assert_failure
  assert_equal "$status" 130
}

@test "fails on invalid result variable name" {
  run menu_select_one "Pick" "Header" "1bad" a b c
  assert_failure
  assert_equal "$status" 130
}

@test "select fallback works with single item" {
  non_interactive_mode() { return 1; }

  # Simulate select choosing first option
  PATH="/usr/bin:/bin" \
  run bash -c '
    export MENU_NON_INTERACTIVE=0
    source ./lib/menu/index.sh
    log_debug(){ :; }; log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }

    printf "1\n" | {
      menu_select_one "Pick" "Header" result foo 2>/dev/null || exit $?
      echo "RESULT=$result"
    }
  '

  assert_success
  assert_output "RESULT=foo"
}

@test "cancel returns error code 130" {
  PATH="/usr/bin:/bin" \
  run bash -c ' 
    export MENU_NO_FZF=1
    source ./lib/menu/index.sh
    log_debug(){ :; }; log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }

    printf "0\n" | {
      menu_select_one "Pick" "Header" result foo bar || exit $?
    }
  '

  assert_equal "$status" 130
}

@test "fzf path selects first item" {
  run bash -c '
    export MENU_NON_INTERACTIVE=0
    export PATH="$(pwd)/test/helpers:$PATH"
    export FAKE_FZF_MODE=select
    unset MENU_NO_FZF

    source ./lib/menu/index.sh
    log_debug(){ :; }; log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }

    menu_select_one "Pick" "Header" result foo bar || exit $?
    echo "$result"
  '

  assert_success
  assert_line --index 0 "foo"
}

@test "fzf cancel returns error code 130" {
  run bash -c '
    export PATH="$(pwd)/test/helpers:$PATH"
    export FAKE_FZF_MODE=cancel
    unset MENU_NO_FZF

    source ./lib/menu/index.sh
    log_debug(){ :; }; log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }

    menu_select_one "Pick" "Header" result foo bar || exit $?
  '

  assert_equal "$status" 130
}
