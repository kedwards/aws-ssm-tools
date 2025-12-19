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

  # Never authenticate during help or dry-run
  [[ "${SHOW_HELP:-false}" == true ]] && return 0
  [[ "${DRY_RUN:-false}" == true ]] && return 0

  # Already authenticated (env creds OR STS)
  if aws_auth_is_valid || aws_auth_detected; then
    log_debug "AWS credentials already present"
    return 0
  fi

  # Not authenticated - provide helpful error
  log_error "No AWS credentials found"
  log_error ""
  log_error "Please authenticate first using ONE of:"
  log_error "  1. Run: assume $profile -r $region"
  log_error "  2. Set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN"
  log_error "  3. Configure ~/.aws/credentials"
  log_error ""
  log_error "Then run your ssm command again."
  return 1
}
