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
  echo "Active SSM sessions (Current profile: $current_profile):"

  # Find all session-manager-plugin processes
  mapfile -t lines < <(ps aux | grep "session-manager-plugin" | grep -v grep || true)
  
  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "  (none found)"
    return 0
  fi

  local line
  for line in "${lines[@]}"; do
    local pid target host port session_type instance_name
    
    # Extract PID (2nd field in ps aux output)
    pid=$(awk '{print $2}' <<<"$line")
    
    # Extract target instance ID - try --target flag first
    target=$(grep -oP '\-\-target \K[^ ]+' <<<"$line" || true)
    
    # If no --target flag, try to extract from JSON
    if [[ -z "$target" ]]; then
      target=$(sed -n 's/.*TargetId":"\([^"]*\)".*/\1/p' <<<"$line" | head -n1)
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
    if [[ -n "$target" ]]; then
      instance_name=$(aws ec2 describe-instances --instance-ids "$target" \
        --query "Reservations[0].Instances[0].Tags[?Key=='Name'].Value" \
        --output text 2>/dev/null || echo "")
    fi
    
    # Display session info
    if [[ -n "$instance_name" && "$instance_name" != "None" ]]; then
      echo "  PID: $pid | $session_type | Instance: $instance_name (${target:-unknown})"
    else
      echo "  PID: $pid | $session_type | Instance: ${target:-unknown}"
    fi
  done
  
  echo ""
  echo "Tip: Switch to the correct AWS profile to see instance names"
}
