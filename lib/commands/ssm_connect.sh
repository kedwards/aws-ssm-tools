#!/usr/bin/env bash

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$THIS_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/core/interaction.sh"
source "$ROOT_DIR/lib/menu/index.sh"


ssm_connect_usage() {
  cat <<EOF
Usage: ssm connect [OPTIONS] [INSTANCE]

Options:
  --config               Config-based port forwarding
  -f, --file FILE        Config file override
  -h, --help
EOF
}

ssm_connect() {
  parse_common_flags "$@" || return 1

  if [[ "$SHOW_HELP" == true ]]; then
    ssm_connect_usage
    return 0
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
    && [[ -z "${INSTANCES_ARG:-}" ]] \
    && [[ "${MENU_ASSUME_FIRST:-0}" != "1" ]]; then
    log_error "Instance selection requires interaction"
    log_error "or pass instance ID"
    return 1
  fi

  #  Skip auth entirely in help
  [[ "${SHOW_HELP:-false}" == true ]] && return 0

  # Only authenticate if we're actually going to execute
  aws_auth_assume "$PROFILE" "$REGION" || return 1

  local instance instance_name instance_id
  local subheader="Profile: ${PROFILE:-${AWS_PROFILE:-unknown}} | Region: ${REGION:-${AWS_REGION:-unknown}}"
  instance=$(aws_ec2_select_instance "Select instance to connect to" "$target" "$subheader") || return 130

  instance_name="${instance% *}"
  instance_id="${instance##* }"
  
  aws_ssm_start_shell "$instance_id"
}

ssm_connect_config_mode() {
  if non_interactive_mode && [[ "${MENU_ASSUME_FIRST:-0}" != "1" ]]; then
    log_error "Config selection requires interaction"
    return 1
  fi

  local default_config="$HOME/.local/share/aws-ssm-tools/connections.config"
  local user_config="$HOME/.config/aws-ssm-tools/connections.user.config"
  local custom_config="${CONFIG_FILE:-}"

  # Collect all config files that exist
  local config_files=()
  [[ -f "$default_config" ]] && config_files+=("$default_config")
  [[ -f "$user_config" ]] && config_files+=("$user_config")
  [[ -n "$custom_config" && -f "$custom_config" ]] && config_files+=("$custom_config")

  if (( ${#config_files[@]} == 0 )); then
    log_error "No connection config files found"
    log_error "Checked: $default_config, $user_config"
    return 1
  fi

  # Extract all sections from all config files (later files can override)
  local -A connection_map
  local file
  for file in "${config_files[@]}"; do
    while IFS= read -r section; do
      connection_map["$section"]="$file"
    done < <(
      sed -nE '
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
          s/^[[:space:]]*\[//;
          s/\][[:space:]]*$//;
          p
        }
      ' "$file"
    )
  done

  # Build connection list
  mapfile -t connections < <(printf '%s\n' "${!connection_map[@]}" | sort)

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

  # Get the config file that contains this connection
  local cfg="${connection_map[$conn]}"

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
  local subheader="Profile: ${PROFILE:-default} | Region: ${REGION:-${AWS_DEFAULT_REGION:-unknown}}"
  instance=$(aws_ec2_select_instance "Select instance" "$name" "$subheader") || return 130
  local instance_id="${instance##* }"

  # log_info "Starting port forward: $instance_name ($instance_id)"
  aws_ssm_start_port_forward "$instance_id" "$host" "$port" "$local_port" &

  [[ -n "$url" ]] && sleep 2 && open_browser "$url" || true
}
