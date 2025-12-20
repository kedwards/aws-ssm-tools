#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWS_EC2_DISABLE_LIVE_CALLS=1
export AWS_AUTH_DISABLE_ASSUME=1

setup() {
  # Stub logging
  log_debug() { :; }
  log_info() { :; }
  log_warn() { :; }
  log_error() { :; }
  export -f log_debug log_info log_warn log_error

  # Set ROOT_DIR for sourcing
  ROOT_DIR="$(pwd)"
  export ROOT_DIR

  # Stub ps command
  ps() {
    if [[ "$1" == "aux" || "$1" == "eww" ]]; then
      cat "$PS_OUTPUT_FILE"
      return 0
    fi
    if [[ "$1" == "-p" ]]; then
      # Check if PID exists (for kill verification)
      return 1  # Process doesn't exist
    fi
    if [[ "$1" == "-o" && "$2" == "ppid=" ]]; then
      # Return parent PID (one more than child for testing)
      local child_pid="${4:-}"
      echo "$((child_pid + 10000))"
      return 0
    fi
    command ps "$@"
  }
  export -f ps

  # Stub kill command - track kills in a file
  KILL_LOG="$(mktemp)"
  export KILL_LOG
  kill() {
    if [[ "$1" == "-9" ]]; then
      echo "SIGKILL:$2" >> "$KILL_LOG"
    else
      echo "SIGTERM:$1" >> "$KILL_LOG"
    fi
    return 0
  }
  export -f kill

  # Create temp file for ps output
  PS_OUTPUT_FILE="$(mktemp)"
  export PS_OUTPUT_FILE
}

teardown() {
  rm -f "$PS_OUTPUT_FILE" "$KILL_LOG"
}

# ssm_kill tests

@test "ssm_kill shows help with --help" {
  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: ssm kill" ]]
}

@test "ssm_kill shows no sessions when none found" {
  echo "" > "$PS_OUTPUT_FILE"
  
  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No active SSM sessions found" ]]
}

@test "ssm_kill extracts PID from selection" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-abc123
EOF

  # Mock menu_select_many to return a selection (output to stdout)
  menu_select_many() {
    printf '%s' "PID: 22345|12345 | Interactive Shell | Instance: i-abc123"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Killing SSM session (PIDs: 22345, 12345)" ]]
  killed=$(cat "$KILL_LOG")
  [[ "$killed" =~ "22345" ]]
  [[ "$killed" =~ "12345" ]]
}

@test "ssm_kill sends SIGTERM first" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     99999  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-test
EOF

  menu_select_many() {
    printf '%s' "PID: 109999|99999 | Interactive Shell | Instance: i-test"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  killed=$(cat "$KILL_LOG")
  [[ "$killed" =~ "SIGTERM:109999" ]]
  [[ "$killed" =~ "SIGTERM:99999" ]]
}

@test "ssm_kill handles cancelled selection" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-abc123
EOF

  # Mock menu to return error (cancelled)
  menu_select_many() {
    return 1
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 1 ]
  [ ! -s "$KILL_LOG" ]  # File should be empty
}

@test "ssm_kill handles empty selection" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-abc123
EOF

  menu_select_many() {
    printf '%s' ""
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No sessions selected" ]]
  [ ! -s "$KILL_LOG" ]  # File should be empty
}

@test "ssm_kill handles multiple sessions" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     11111  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-aaa
user     22222  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-bbb
EOF

  menu_select_many() {
    printf '%s\n%s' "PID: 21111|11111 | Interactive Shell | Instance: i-aaa" "PID: 32222|22222 | Interactive Shell | Instance: i-bbb"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(PIDs: 21111, 11111)" ]]
  [[ "$output" =~ "(PIDs: 32222, 22222)" ]]
  kill_count=$(wc -l < "$KILL_LOG")
  [ "$kill_count" -eq 4 ]  # 2 parents + 2 children
}

@test "ssm_kill correctly identifies both parent and child PIDs" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     54321  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-xyz789
EOF

  # Mock ps to return specific parent PID
  ps() {
    if [[ "$1" == "aux" || "$1" == "eww" ]]; then
      cat "$PS_OUTPUT_FILE"
      return 0
    fi
    if [[ "$1" == "-o" && "$2" == "ppid=" ]]; then
      # Return parent PID (64321 for child 54321)
      echo "64321"
      return 0
    fi
    if [[ "$1" == "-p" ]]; then
      return 1  # Process doesn't exist after kill
    fi
    command ps "$@"
  }
  export -f ps

  menu_select_many() {
    printf '%s' "PID: 64321|54321 | Interactive Shell | Instance: i-xyz789"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Killing SSM session (PIDs: 64321, 54321)" ]]
  # Verify both PIDs appear in kill log
  killed=$(cat "$KILL_LOG")
  [[ "$killed" =~ "64321" ]]  # parent PID
  [[ "$killed" =~ "54321" ]]  # child PID
}

@test "ssm_kill attempts to kill both parent and child processes" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     77777  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-test123
EOF

  menu_select_many() {
    printf '%s' "PID: 87777|77777 | Interactive Shell | Instance: i-test123"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  
  # Verify both parent and child PIDs were killed
  killed=$(cat "$KILL_LOG")
  [[ "$killed" =~ "SIGTERM:87777" ]]  # parent should be killed first
  [[ "$killed" =~ "SIGTERM:77777" ]]  # child should be killed second
  
  # Verify we have exactly 2 SIGTERM entries (parent + child)
  sigterm_count=$(grep -c "SIGTERM" "$KILL_LOG")
  [ "$sigterm_count" -eq 2 ]
}

@test "ssm_kill successfully terminates session by killing both processes" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     33333  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-complete
EOF

  # Override log_info to echo output for this test
  log_info() { echo "$@"; }
  export -f log_info

  menu_select_many() {
    printf '%s' "PID: 43333|33333 | Interactive Shell | Instance: i-complete"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Session terminated (PIDs: 43333, 33333)" ]]
  
  # Verify no force kill was needed (only SIGTERM, no SIGKILL)
  killed=$(cat "$KILL_LOG")
  [[ "$killed" =~ "SIGTERM" ]]
  [[ ! "$killed" =~ "SIGKILL" ]]
}

@test "ssm_kill attempts force kill if processes still running after initial termination" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     55555  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-stubborn
EOF

  # Mock ps to indicate processes are still running after SIGTERM
  ps() {
    if [[ "$1" == "aux" || "$1" == "eww" ]]; then
      cat "$PS_OUTPUT_FILE"
      return 0
    fi
    if [[ "$1" == "-o" && "$2" == "ppid=" ]]; then
      echo "65555"
      return 0
    fi
    if [[ "$1" == "-p" ]]; then
      local pid="$2"
      # Check if we've done a SIGKILL for this specific PID
      if grep -q "SIGKILL:$pid" "$KILL_LOG" 2>/dev/null; then
        # After SIGKILL, process is gone
        return 1
      else
        # Before SIGKILL, process still exists
        return 0
      fi
    fi
    command ps "$@"
  }
  export -f ps

  menu_select_many() {
    printf '%s' "PID: 65555|55555 | Interactive Shell | Instance: i-stubborn"
    return 0
  }
  export -f menu_select_many

  aws() { return 1; }
  export -f aws

  source ./lib/commands/ssm_kill.sh
  
  run ssm_kill
  [ "$status" -eq 0 ]
  [[ "$output" =~ "still running, forcing kill" ]]
  
  # Verify SIGTERM was sent first
  killed=$(cat "$KILL_LOG")
  [[ "$killed" =~ "SIGTERM:65555" ]]
  [[ "$killed" =~ "SIGTERM:55555" ]]
  
  # Verify SIGKILL (kill -9) was sent after
  [[ "$killed" =~ "SIGKILL:65555" ]]
  [[ "$killed" =~ "SIGKILL:55555" ]]
  
  # Verify order: SIGTERM before SIGKILL
  first_signal=$(head -n1 "$KILL_LOG")
  [[ "$first_signal" =~ "SIGTERM" ]]
}
