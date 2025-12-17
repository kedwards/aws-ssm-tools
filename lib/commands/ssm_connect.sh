#!/usr/bin/env bash

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$THIS_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/core/interaction.sh"
source "$ROOT_DIR/lib/menu/index.sh"


ssm_connect_usage() {
  cat <<EOF
Usage: ssm connect [OPTIONS] [INSTANCE]

Options:
  -p, --profile PROFILE
  -r, --region REGION
  -c, --config           Config-based port forwarding
  -f, --file FILE        Config file override
  -n, --dry-run          Show what would be executed, do not run
  -h, --help
EOF
}

DRY_RUN=false

ssm_connect() {
  parse_common_flags "$@" || return 1

  if [[ "$SHOW_HELP" == true ]]; then
    ssm_connect_usage
    return 0
  fi

  # DRY-RUN: skip auth entirely
  if [[ "$DRY_RUN" == true ]]; then
    if [[ "$CONFIG_MODE" == true ]]; then
      ssm_connect_config_mode
    else
      ssm_connect_shell_mode
    fi
    return $?
  fi

  if [[ "$CONFIG_MODE" == true ]]; then
    ssm_connect_config_mode
  else
    ssm_connect_shell_mode
  fi
}

ssm_connect_shell_mode() {
  local target="${INSTANCES_ARG:-}"
  [[ -z "$target" && ${#POSITIONAL[@]} -gt 0 ]] && target="${POSITIONAL[0]}"

  if non_interactive_mode \
    && [[ "$DRY_RUN" != true ]] \
    && [[ -z "${INSTANCES_ARG:-}" ]] \
    && [[ "${MENU_ASSUME_FIRST:-0}" != "1" ]]; then
    log_error "Instance selection requires interaction"
    log_error "Use --yes or pass instance ID"
    return 1
  fi

  #  Skip auth entirely in help
  [[ "${SHOW_HELP:-false}" == true ]] && return 0

  if [[ "$DRY_RUN" == true ]]; then
    if [[ "$target" == i-* ]]; then
      echo "DRY-RUN: aws ssm start-session --target $target"
    else
      echo "DRY-RUN: aws ssm start-session --target <instance-id>"
    fi
    return 0
  fi

  local instance instance_name instance_id
  instance=$(aws_ec2_select_instance "Select instance to connect to" "$target") || return 130

  # Only authenticate if we're actually going to execute
  aws_auth_assume "$PROFILE" "$REGION" || return 1

  instance_name="${instance% *}"
  instance_id="${instance##* }"
  
  aws_ssm_start_shell "$instance_id"
}

ssm_connect_config_mode() {
  if non_interactive_mode && [[ "${MENU_ASSUME_FIRST:-0}" != "1" ]]; then
    log_error "Config selection requires interaction"
    return 1
  fi

  local cfg="${CONFIG_FILE:-${SSMF_CONF:-$HOME/.ssmf.cfg}}"
  [[ ! -f "$cfg" ]] && log_error "Config not found: $cfg" && return 1

  mapfile -t connections < <(
    sed -nE '
      /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
        s/^[[:space:]]*\[//;
        s/\][[:space:]]*$//;
        p
      }
    ' "$cfg"
  )

  if (( ${#connections[@]} == 0 )); then
    log_error "No [sections] found in config file: $cfg"
    return 1
  fi

  local conn

  if non_interactive_mode; then
    conn="${connections[0]}"
  else
    menu_select_one "Select connection" "" conn "${connections[@]}" || return 130
  fi

  local profile region port local_port host url name
  profile=$(aws_ssm_config_get "$cfg" "$conn" profile)
  region=$(aws_ssm_config_get "$cfg" "$conn" region)
  port=$(aws_ssm_config_get "$cfg" "$conn" port)

  local_port=$(aws_ssm_config_get "$cfg" "$conn" local_port)
  host=$(aws_ssm_config_get "$cfg" "$conn" host)
  url=$(aws_ssm_config_get "$cfg" "$conn" url)
  name=$(aws_ssm_config_get "$cfg" "$conn" name)

  local_port="${local_port:-$port}"
  host="${host:-localhost}"

  PROFILE="$profile"
  REGION="$region"

  choose_profile_and_region || return 1
  aws_auth_assume "$PROFILE" "$REGION" || return 1

  local instance
  instance=$(aws_ec2_select_instance "Select instance" "$name") || return 130
  local instance_id="${instance##* }"

  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY-RUN: aws ssm start-session --target $instance_id \\"
    echo "  --document-name AWS-StartPortForwardingSessionToRemoteHost \\"
    echo "  --parameters host=$host port=$port local=$local_port"
    return 0
  fi

  # log_info "Starting port forward: $instance_name ($instance_id)"
  aws_ssm_start_port_forward "$instance_id" "$host" "$port" "$local_port" &

  [[ -n "$url" ]] && sleep 2 && open_browser "$url" || true
}
