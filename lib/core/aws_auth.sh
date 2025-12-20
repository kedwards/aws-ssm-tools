#!/usr/bin/env bash

LIB_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_CORE_DIR/interaction.sh"
source "$LIB_CORE_DIR/test_guard.sh"

aws_auth_detected() {
  aws sts get-caller-identity >/dev/null 2>&1
}

aws_auth_is_valid() {
  [[ -n "${AWS_ACCESS_KEY_ID:-}" &&
     -n "${AWS_SECRET_ACCESS_KEY:-}" &&
     -n "${AWS_SESSION_TOKEN:-}" ]]
}

guard_function_override aws_auth_assume || aws_auth_assume() {
  local profile="${1:-${PROFILE:-}}"
  local region="${2:-${REGION:-}}"

  # Never authenticate during help
  [[ "${SHOW_HELP:-false}" == true ]] && return 0

  # Check if already authenticated
  if ! (aws_auth_is_valid || aws_auth_detected); then
    log_error "No AWS credentials found"
    log_error "Authenticate first with: assume <profile> -r <region>"
    log_error "Or run: ssm login"
    return 1
  fi

  # Validate we're using the expected profile/region if specified
  if [[ -n "$profile" ]]; then
    local current_profile="${AWS_PROFILE:-}"
    if [[ -n "$current_profile" && "$current_profile" != "$profile" ]]; then
      log_error "Currently authenticated with profile '$current_profile'"
      log_error "Requested profile '$profile'"
      log_error "Run 'assume $profile' to switch profiles"
      return 1
    fi
  fi

  if [[ -n "$region" ]]; then
    local current_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
    if [[ -n "$current_region" && "$current_region" != "$region" ]]; then
      log_error "Currently authenticated with region '$current_region'"
      log_error "Requested region '$region'"
      log_error "Run 'assume <profile> -r $region' to switch regions"
      return 1
    fi
  fi

  return 0
}
