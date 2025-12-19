#!/usr/bin/env bash
set -euo pipefail

ssm_login_usage() {
  cat <<EOF
Usage: ssm login [OPTIONS]

Authenticate to AWS via Granted (SSO).

This command provides instructions for authenticating with AWS using Granted.
Due to shell limitations, you must run the assume command directly in your shell.

Options:
  -p, --profile PROFILE  AWS profile to use (optional - will prompt if not provided)
  -r, --region  REGION   AWS region to use (optional - will use profile default)
  -h, --help             Show this help message

Examples:
  ssm login                  # Interactive - select profile and region
  ssm login -p prod          # Use 'prod' profile
  ssm login -p prod -r us-west-2

Note: This command will display the exact 'assume' command you need to run.
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
    log_error "Install from: https://granted.dev"
    return 1
  fi

  # Check if already authenticated
  if aws sts get-caller-identity >/dev/null 2>&1; then
    local current_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
    local current_user=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unknown")
    log_success "Already authenticated to AWS"
    log_info "Account: $current_account"
    log_info "User/Role: $current_user"
    echo ""
    log_info "To switch profiles, run:"
    echo "  assume $PROFILE -r $REGION"
    return 0
  fi

  # Not authenticated - provide instructions
  echo ""
  echo "═══════════════════════════════════════════════════════════════════"
  echo "  AWS AUTHENTICATION REQUIRED"
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""
  log_info "To authenticate with AWS SSO, run this command in your shell:"
  echo ""
  echo "  assume $PROFILE -r $REGION"
  echo ""
  log_warn "IMPORTANT: This command must be run directly in your terminal"
  log_warn "           (not from a script) to export credentials properly."
  echo ""
  echo "After authentication, all ssm commands will work:"
  echo "  • ssm connect    - Connect to instances"
  echo "  • ssm exec       - Execute commands on multiple instances"
  echo "  • ssm list       - List active sessions  "
  echo "  • ssm kill       - Terminate sessions"
  echo ""
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""

  return 0
}
