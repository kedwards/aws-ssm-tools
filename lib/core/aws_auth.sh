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
    return 0
  fi

  # Non-interactive → FAIL FAST (before tooling checks)
  if non_interactive_mode; then
    log_error "Interaction is disabled"
    log_error "Run interactively:"
    log_error "  assume ${profile:-<profile>} -r ${region:-<region>}"
    return 1
  fi

  # Interactive only: tooling checks
  if ! command -v assume >/dev/null 2>&1; then
    log_error "'assume' command not found (install Granted)"
    return 1
  fi

  log_info "Authenticating with Granted (profile=$profile, region=$region)"

  if ! assume "$profile" -r "$region"; then
    log_error "Failed to assume AWS profile"
    return 1
  fi

  if ! aws_auth_is_valid; then
    log_error "Granted login did not produce valid AWS credentials"
    return 1
  fi

  # Explicitly export (do NOT rely on Granted)
  export AWS_PROFILE="$profile"
  export AWS_REGION="$region"

  return 0
}
