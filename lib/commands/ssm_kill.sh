#!/usr/bin/env bash

ssm_kill_usage() {
  cat <<EOF
Usage: ssm kill

Interactively select and terminate SSM sessions on this host.
EOF
}

ssm_kill() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    ssm_kill_usage
    return 0
  fi

  # Find all session-manager-plugin processes (with environment)
  mapfile -t sessions < <(ps eww aux | grep "[s]ession-manager-plugin" || true)
  
  if [[ ${#sessions[@]} -eq 0 ]]; then
    echo "No active SSM sessions found."
    return 0
  fi

  # Build session list for display
  local session_list=()
  local line
  for line in "${sessions[@]}"; do
    local pid ppid target host port session_type instance_name profile region
    
    # Extract PID (session-manager-plugin child process)
    pid=$(awk '{print $2}' <<<"$line")
    
    # Get parent PID (the 'aws ssm start-session' command)
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || echo "")
    [[ -z "$ppid" ]] && ppid="$pid"  # Fallback to child if parent lookup fails
    
    # Extract profile from environment
    profile=$(echo "$line" | grep -oP 'AWS_PROFILE=\K[^ ]+' | head -n1)
    [[ -z "$profile" ]] && profile="unknown"
    
    # Extract region
    region=$(echo "$line" | grep -oP 'session-manager-plugin\s+\S+\s+\K[a-z]{2}-[a-z]+-\d+' | head -n1)
    if [[ -z "$region" ]]; then
      region=$(echo "$line" | grep -oP 'ssm\.\K[a-z]{2}-[a-z]+-\d+' | head -n1)
    fi
    
    # Extract target
    target=$(grep -oP '\-\-target \K[^ ]+' <<<"$line" || true)
    if [[ -z "$target" ]]; then
      target=$(sed -n 's/.*TargetId":"\([^"]*\)".*/\1/p' <<<"$line" | head -n1)
    fi
    
    # Determine session type
    if grep -q "StartPortForwardingSessionToRemoteHost" <<<"$line"; then
      port=$(grep -oP 'localPortNumber.*?\K\d+' <<<"$line" | head -n1)
      host=$(grep -oP '"host".*?\K[a-zA-Z0-9._-]+' <<<"$line" | head -n1)
      [[ -z "$host" ]] && host="localhost"
      session_type="Port: ${port:-?} -> ${host}"
    elif grep -q "StartPortForwardingSession" <<<"$line"; then
      port=$(grep -oP 'localPortNumber.*?\K\d+' <<<"$line" | head -n1)
      host=$(grep -oP 'DestinationHost.*?\K[a-zA-Z0-9._-]+' <<<"$line" | head -n1)
      [[ -z "$host" ]] && host="localhost"
      session_type="Port: ${port:-?} -> ${host}"
    else
      session_type="Interactive Shell"
    fi
    
    # Try to resolve instance name
    instance_name=""
    if [[ -n "$target" ]]; then
      instance_name=$(aws ec2 describe-instances --instance-ids "$target" \
        --query "Reservations[0].Instances[0].Tags[?Key=='Name'].Value" \
        --output text 2>/dev/null || echo "")
    fi
    
    # Build display string
    local region_display=""
    if [[ -n "$region" ]]; then
      region_display=" | Region: $region"
    fi
    
    local profile_display=""
    if [[ -n "$profile" && "$profile" != "unknown" ]]; then
      profile_display=" | Profile: $profile"
    fi
    
    # Add to list (store both PIDs: parent|child for killing entire tree)
    if [[ -n "$instance_name" && "$instance_name" != "None" ]]; then
      session_list+=("PID: $ppid|$pid | $session_type | Instance: $instance_name (${target:-unknown})${region_display}${profile_display}")
    else
      session_list+=("PID: $ppid|$pid | $session_type | Instance: ${target:-unknown}${region_display}${profile_display}")
    fi
  done

  # Interactive multi-select
  local selected
  selected=$(menu_select_many "Select SSM sessions to kill" "Use TAB to select multiple, ENTER to confirm" unused "${session_list[@]}")
  local ret=$?
  
  if [[ $ret -ne 0 ]]; then
    return $ret
  fi

  if [[ -z "${selected:-}" ]]; then
    echo "No sessions selected"
    return 0
  fi

  # Kill selected sessions
  while IFS= read -r sel; do
    [[ -z "$sel" ]] && continue
    
    # Extract PIDs (format: "PID: parent|child | ...")
    local pids
    pids=$(grep -oP 'PID: \K[0-9|]+' <<<"$sel" || true)
    
    if [[ -n "$pids" ]]; then
      # Split parent|child
      local parent_pid="${pids%%|*}"
      local child_pid="${pids##*|}"
      
      echo "Killing SSM session (PIDs: $parent_pid, $child_pid)"
      
      # Kill parent first (the 'aws ssm start-session' command)
      if kill "$parent_pid" 2>/dev/null; then
        sleep 0.2
      else
        log_warn "Failed to kill parent process $parent_pid (may already be terminated)"
      fi
      
      # Kill child (the session-manager-plugin)
      if kill "$child_pid" 2>/dev/null; then
        sleep 0.2
      else
        log_warn "Failed to kill child process $child_pid (may already be terminated)"
      fi
      
      # Force kill if still running
      sleep 0.3
      if ps -p "$parent_pid" >/dev/null 2>&1; then
        echo "  Parent process still running, forcing kill..."
        kill -9 "$parent_pid" 2>/dev/null || true
      fi
      
      if ps -p "$child_pid" >/dev/null 2>&1; then
        echo "  Child process still running, forcing kill..."
        kill -9 "$child_pid" 2>/dev/null || true
      fi
      
      # Verify termination
      local still_running=false
      if ps -p "$parent_pid" >/dev/null 2>&1 || ps -p "$child_pid" >/dev/null 2>&1; then
        still_running=true
      fi
      
      if [[ "$still_running" == true ]]; then
        log_error "Failed to terminate session (PIDs: $parent_pid, $child_pid)"
      else
        log_info "Session terminated (PIDs: $parent_pid, $child_pid)"
      fi
    fi
  done <<<"$selected"
}
