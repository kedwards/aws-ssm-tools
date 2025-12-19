#!/usr/bin/env bash

ssm_list_usage() {
  cat <<EOF
Usage: ssm list

List active SSM sessions on this host.
EOF
}

ssm_list() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    ssm_list_usage
    return 0
  fi

  local current_profile="${AWS_PROFILE:-none}"
  local current_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-none}}"
  echo "Active SSM sessions (Current profile: $current_profile, Current region: $current_region):"

  # Find all session-manager-plugin processes (with environment)
  mapfile -t lines < <(ps eww aux | grep "session-manager-plugin" | grep -v grep || true)
  
  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "  (none found)"
    return 0
  fi

  local line
  for line in "${lines[@]}"; do
    local pid target host port session_type instance_name region profile
    
    # Extract PID (2nd field in ps aux output)
    pid=$(awk '{print $2}' <<<"$line")
    
    # Extract profile from environment variables in ps output
    profile=$(echo "$line" | grep -oP 'AWS_PROFILE=\K[^ ]+' | head -n1)
    [[ -z "$profile" ]] && profile="unknown"
    
    # Extract region (typically 3rd argument after session-manager-plugin)
    # Format: session-manager-plugin AWS_SSM_START_SESSION_RESPONSE us-west-2 ...
    region=$(echo "$line" | grep -oP 'session-manager-plugin\s+\S+\s+\K[a-z]{2}-[a-z]+-\d+' | head -n1)
    if [[ -z "$region" ]]; then
      # Fallback: extract from SSM endpoint URL
      region=$(echo "$line" | grep -oP 'ssm\.\K[a-z]{2}-[a-z]+-\d+' | head -n1)
    fi
    
    # Extract target instance ID from the JSON parameter
    # Format: {"Target": "i-xxxxx"}
    target=$(grep -oP '"Target"\s*:\s*"\K[^"]+' <<<"$line" || true)
    
    # Fallback: try --target flag format
    if [[ -z "$target" ]]; then
      target=$(grep -oP '\-\-target \K[^ ]+' <<<"$line" || true)
    fi
    
    # Fallback: try TargetId in JSON
    if [[ -z "$target" ]]; then
      target=$(grep -oP '"TargetId"\s*:\s*"\K[^"]+' <<<"$line" || true)
    fi
    
    # Determine session type
    if grep -q "StartPortForwardingSessionToRemoteHost" <<<"$line"; then
      # Port forwarding to remote host
      port=$(grep -oP 'localPortNumber.*?\K\d+' <<<"$line" | head -n1)
      host=$(grep -oP '"host".*?\K[a-zA-Z0-9._-]+' <<<"$line" | head -n1)
      [[ -z "$host" ]] && host="localhost"
      session_type="Port: ${port:-?} -> ${host}"
    elif grep -q "StartPortForwardingSession" <<<"$line"; then
      # Port forwarding to instance
      port=$(grep -oP 'localPortNumber.*?\K\d+' <<<"$line" | head -n1)
      host=$(grep -oP 'DestinationHost.*?\K[a-zA-Z0-9._-]+' <<<"$line" | head -n1)
      [[ -z "$host" ]] && host="localhost"
      session_type="Port: ${port:-?} -> ${host}"
    else
      # Interactive shell session
      session_type="Interactive Shell"
    fi
    
    # Try to resolve instance name from EC2 (optional, may fail if wrong profile)
    instance_name=""
    if [[ -n "$target" && "$target" =~ ^i- ]]; then
      # Only try to resolve if target looks like an instance ID
      instance_name=$(aws ec2 describe-instances --instance-ids "$target" \
        --query "Reservations[0].Instances[0].Tags[?Key=='Name'].Value | [0]" \
        --output text 2>/dev/null || echo "")
      
      # Filter out "None" responses
      if [[ "$instance_name" == "None" || -z "$instance_name" ]]; then
        instance_name=""
      fi
    fi
    
    # Display session info
    local region_display=""
    if [[ -n "$region" ]]; then
      region_display=" | Region: $region"
    fi
    
    local profile_display=""
    if [[ -n "$profile" && "$profile" != "unknown" ]]; then
      profile_display=" | Profile: $profile"
    fi
    
    if [[ -n "$instance_name" && "$instance_name" != "None" ]]; then
      echo "  PID: $pid | $session_type | Instance: $instance_name (${target:-unknown})${region_display}${profile_display}"
    else
      echo "  PID: $pid | $session_type | Instance: ${target:-unknown}${region_display}${profile_display}"
    fi
  done
  
  echo ""
  
  # Show helpful tip about authentication
  if [[ "$current_profile" == "none" ]]; then
    echo "Note: No AWS profile set. To see instance names, authenticate first:"
    echo "      assume <profile> -r <region>"
  else
    echo "Tip: If instance names don't appear, verify you're using the correct profile"
  fi
}
