#!/usr/bin/env bats

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

load '../helpers/bats-support/load'
load '../helpers/bats-assert/load'

log_debug(){ :; }
log_info(){ :; }
log_warn(){ :; }
log_error(){ :; }

setup() {
  source ./lib/menu/index.sh
}

@test "fails when no items are provided (many)" {
  run menu_select_many "Pick" "Header" result
  assert_failure
}

@test "fzf multi-select returns multiple values" {
  run bash -c '
    export MENU_NON_INTERACTIVE=0
    export PATH="$(pwd)/test/helpers:$PATH"
    export FAKE_FZF_MODE=multi

    log_debug(){ :; }
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ :; }

    source ./lib/menu/index.sh

    menu_select_many "Pick" "Header" result foo bar baz || exit $?
    printf "%s\n" "${result[@]}"
  '

  assert_success
  assert_line --index 0 "foo"
  assert_line --index 1 "bar"
}

@test "fzf multi cancel returns 130" {
  run bash -c '
    export PATH="$(pwd)/test/helpers:$PATH"
    export FAKE_FZF_MODE=cancel
    source ./lib/menu/index.sh

    menu_select_many "Pick" "Header" result foo bar baz || exit $?
  '

  assert_equal "$status" 130
}

@test "fallback multi-select works" {
  non_interactive_mode() { return 1; }

  run bash -c '
    export MENU_NON_INTERACTIVE=0
    export MENU_NO_FZF=1

    log_debug(){ :; }
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ :; }

    source ./lib/menu/index.sh

    printf "1 3\n" | {
      menu_select_many "Pick" "Header" result foo bar baz || exit $?
      printf "%s\n" "${result[@]}"
    }
  '

  assert_success
  assert_line --partial "foo"
  assert_line --partial "baz"
}
