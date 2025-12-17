#!/usr/bin/env bash
set -euo pipefail

ssm_login_usage() {
  cat <<EOF
Usage: ssm login [OPTIONS]

Authenticate to AWS via Granted (SSO).

Options:
  -p, --profile PROFILE
  -r, --region  REGION
  -h, --help
EOF
}

ssm_login() {
  parse_common_flags "$@" || return 1

  if [[ "${SHOW_HELP:-false}" == true ]]; then
    ssm_login_usage
    return 0
  fi

  choose_profile_and_region || return 1

  if ! command -v assume >/dev/null 2>&1; then
    log_error "'assume' (Granted) is required but not installed"
    return 1
  fi

  log_info "Starting interactive SSO login via Granted"
  log_info "Profile: $PROFILE"
  log_info "Region : $REGION"

  # ALWAYS interactive
  if ! assume "$PROFILE" -r "$REGION"; then
    log_error "SSO login failed"
    return 1
  fi

  log_info "Login successful"

  return 0
}
