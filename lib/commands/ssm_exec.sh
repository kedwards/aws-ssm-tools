#!/usr/bin/env bash

set -euo pipefail

ssm_exec_usage() {
  cat <<EOF
Usage: ssm exec [OPTIONS]
       aws-ssm-exec [OPTIONS]
       ssmx [OPTIONS]

Run a shell command via AWS SSM on one or more instances.

Options:
  -c <command>      Command to execute on the instances
  -p <profile>      AWS profile (optionally with region as PROFILE:REGION)
  -r <region>       AWS region (overrides region in profile or -p option)
  -i <instances>    Instance names or IDs (semicolon-separated for multiple)
  -n, --dry-run     Show what would be executed without running
  -y, --yes         Non-interactive mode (auto-select first option)
  -h, --help        Show this help message

Examples:
  ssm exec -c 'ls -lF; uptime' -p prod -i Report                    # single instance
  ssm exec -c 'ls -lF; uptime' -p prod:us-west-2 -i Report          # with region
  ssm exec -c 'ls -lF; uptime' -p prod -r us-west-2 -i Report       # region via -r
  ssm exec -c 'ls -lF; uptime' -p prod -i 'Report;Singleton'        # multiple
  ssm exec -c 'ls -lF; uptime' -p prod                              # interactive instances
  ssm exec -p prod                                                  # interactive command + instances
  ssm exec -c 'ls -lF; uptime'                                      # interactive profile
  ssm exec                                                          # fully interactive

Note: All options are optional and can be combined in any order.
EOF
}

ssm_exec() {
  ensure_aws_cli || return 1

  parse_common_flags "$@" || return 1

  if [[ "${SHOW_HELP:-false}" == true ]]; then
    ssm_exec_usage
    return 0
  fi

  # Command: saved or typed
  if [[ -z "${COMMAND_ARG:-}" ]]; then
    if ! aws_ssm_select_command COMMAND_ARG; then
      log_error "No command selected"
      return 1
    fi
    log_info "Selected command: $COMMAND_ARG"
  fi

  # Validate command is not empty
  if [[ -z "${COMMAND_ARG:-}" ]]; then
    log_error "Command cannot be empty"
    return 1
  fi

  # Auto-detect region from AWS config if profile set but region not
  if [[ -z "${REGION:-}" && -n "${PROFILE:-}" && -f "$HOME/.aws/config" ]]; then
    REGION=$(
      aws configure get profile."$PROFILE".region 2>/dev/null ||
      aws configure get profile."$PROFILE".sso_region 2>/dev/null ||
      true
    )
  fi

  # Profile / region selection and validation
  choose_profile_and_region || return 1
  aws_assume_profile "$PROFILE" "$REGION" || return 1

  # TODO: Instance expansion and selection will be implemented in Step 15
  # TODO: AWS send-command will be implemented in Step 16
  # TODO: Polling will be implemented in Step 17
  # TODO: Output display will be implemented in Step 18

  log_info "ssm_exec skeleton ready - instance handling coming in Step 15"
  return 0
}
