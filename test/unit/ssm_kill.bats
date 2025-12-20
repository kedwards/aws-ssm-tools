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
