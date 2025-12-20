#!/usr/bin/env bash

set -euo pipefail

ssm_exec_usage() {
  cat <<EOF
Usage: ssm exec [OPTIONS]

Run a shell command via AWS SSM on one or more instances.

Note: You must authenticate with AWS before running this command.
      Use 'assume <profile> -r <region>' to authenticate.

Options:
  -c <command>      Command to execute on the instances
  -i <instances>    Instance names or IDs (comma-separated for multiple)
  -h, --help        Show this help message

Examples:
  # Run command on single instance (by name)
  ssm exec -c 'df -h' -i KeyMaster

  # Run command on single instance (by ID)
  ssm exec -c 'df -h' -i i-1234567890abcdef0

  # Run command on multiple instances
  ssm exec -c 'df -h' -i KeyMaster,Admin,i-1234567890abcdef0

  # Interactive instance selection
  ssm exec -c 'uptime'

  # Fully interactive (select command and instances)
  ssm exec
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

  # Validate AWS authentication
  aws_auth_assume "${PROFILE:-}" "${REGION:-}" || return 1

  # Expand instances
  local instance_ids=()
  declare -A instance_name_map  # Map instance ID to name

  if [[ -n "${INSTANCES_ARG:-}" ]]; then
    # Explicit instances via -i flag (comma-separated)
    IFS=',' read -ra instance_names <<<"$INSTANCES_ARG"
    local name
    for name in "${instance_names[@]}"; do
      name="$(echo "$name" | xargs)"  # Trim whitespace
      [[ -z "$name" ]] && continue
      
      # Check if it's an instance ID or name
      if [[ "$name" == i-* ]]; then
        instance_ids+=("$name")
        instance_name_map["$name"]="$name"  # ID as name for IDs
      else
        mapfile -t expanded_ids < <(aws_expand_instances "$name")
        if [[ ${#expanded_ids[@]} -eq 0 ]]; then
          log_warn "No running instance found matching: $name"
        else
          for id in "${expanded_ids[@]}"; do
            instance_ids+=("$id")
            instance_name_map["$id"]="$name"  # Store the original name
          done
        fi
      fi
    done
  else
    # Interactive selection
    aws_get_all_running_instances ""
    if [[ ${#INSTANCE_LIST[@]} -eq 0 ]]; then
      log_error "No running instances found"
      return 1
    fi

    local selections
    selections=$(menu_select_many "Select instances for SSM command" "" unused "${INSTANCE_LIST[@]}")
    local ret=$?
    
    if [[ $ret -ne 0 ]]; then
      return $ret
    fi

    if [[ -z "${selections:-}" ]]; then
      log_error "No instances selected"
      log_error "Hint: Use Tab or Space to mark instances, then press Enter"
      return 1
    fi

    # Extract instance IDs and names from selections (format: "Name i-xxxxx")
    local line
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local inst_id="${line##* }"
      local inst_name="${line% *}"
      instance_ids+=("$inst_id")
      instance_name_map["$inst_id"]="$inst_name"
    done <<<"$selections"
  fi

  if [[ ${#instance_ids[@]} -eq 0 ]]; then
    log_error "No valid instances found"
    return 1
  fi

  log_info "Sending command to ${#instance_ids[@]} instance(s)"

  # Create temp JSON file for AWS CLI
  local tmpfile
  tmpfile=$(mktemp /tmp/ssm-script.XXXXXX)
  trap 'rm -f "${tmpfile:-}"' EXIT

  cat >"$tmpfile" <<EOF
{
  "Parameters": {
    "commands": [
      "#!/bin/bash",
      "$COMMAND_ARG"
    ],
    "executionTimeout": ["600"]
  }
}
EOF

  # Send command via AWS SSM
  local cmd_id
  cmd_id=$(aws ssm send-command \
    --instance-ids "${instance_ids[@]}" \
    --document-name "AWS-RunShellScript" \
    --cli-input-json "file://$tmpfile" \
    --query 'Command.CommandId' \
    --output text)

  local send_ret=$?
  if [[ $send_ret -ne 0 ]]; then
    log_error "Failed to send command"
    return 1
  fi

  # Get account info
  local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
  local current_profile="${AWS_PROFILE:-unknown}"
  local current_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-unknown}}"
  
  echo ""
  echo "═══════════════════════════════════════════════════════════════════"
  echo "  SSM COMMAND EXECUTION"
  echo "═══════════════════════════════════════════════════════════════════"
  echo "Account:     $account_id"
  echo "Profile:     $current_profile"
  echo "Region:      $current_region"
  echo "Command:     $COMMAND_ARG"
  echo "Command ID:  $cmd_id"
  echo "Instances:   ${#instance_ids[@]}"
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""
  
  local n_instances="${#instance_ids[@]}"

  # Poll for completion
  log_info "Waiting for command completion..."
  while true; do
    local finished=0
    local inst
    for inst in "${instance_ids[@]}"; do
      local status
      status=$(aws ssm get-command-invocation \
        --command-id "$cmd_id" \
        --instance-id "$inst" \
        --query Status \
        --output text 2>/dev/null | tr 'A-Z' 'a-z')
      local now
      now=$(date +%H:%M:%S)
      echo "  [$now] $inst: $status"
      case "$status" in
        pending|inprogress|delayed) : ;;
        *) finished=$((finished+1)) ;;
      esac
    done
    [[ $finished -ge $n_instances ]] && break
    sleep 2
  done
  echo ""

  # Display results
  log_info "Command execution completed"
  echo ""
  
  for inst in "${instance_ids[@]}"; do
    local status out err instance_name
    
    # Get status and output
    status=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" \
      --instance-id "$inst" \
      --query Status --output text 2>/dev/null) || status="Unknown"
    out=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" \
      --instance-id "$inst" \
      --query StandardOutputContent --output text 2>/dev/null) || out=""
    err=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" \
      --instance-id "$inst" \
      --query StandardErrorContent --output text 2>/dev/null) || err=""
    
    # Get instance name from map
    instance_name="${instance_name_map[$inst]:-}"
    
    # Header
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    if [[ -n "$instance_name" ]]; then
      printf "│ %-67s │\n" "Instance: $instance_name"
    fi
    printf "│ %-67s │\n" "ID: $inst"
    printf "│ %-67s │\n" "Profile: $current_profile"
    printf "│ %-67s │\n" "Region: $current_region"
    printf "│ %-67s │\n" "Status: $status"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    
    # Output
    if [[ -n "$out" ]]; then
      echo "┌─ STDOUT ────────────────────────────────────────────────────────────┐"
      echo "$out"
      echo "└─────────────────────────────────────────────────────────────────────┘"
    fi
    
    # Errors
    if [[ -n "$err" ]]; then
      echo "┌─ STDERR ────────────────────────────────────────────────────────────┐"
      echo "$err"
      echo "└─────────────────────────────────────────────────────────────────────┘"
    fi
    
    # No output
    if [[ -z "$out" && -z "$err" ]]; then
      echo "┌─────────────────────────────────────────────────────────────────────┐"
      printf "│ %-67s │\n" "No output returned"
      echo "└─────────────────────────────────────────────────────────────────────┘"
    fi
    
    echo ""
  done
  
  echo "═══════════════════════════════════════════════════════════════════"
  echo "  Execution complete for ${#instance_ids[@]} instance(s)"
  echo "═══════════════════════════════════════════════════════════════════"

  return 0
}
