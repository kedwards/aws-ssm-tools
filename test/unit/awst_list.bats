#!/usr/bin/env bats
# shellcheck disable=SC2034

export MENU_NON_INTERACTIVE=1
export AWST_EC2_DISABLE_LIVE_CALLS=1
export AWST_AUTH_DISABLE_ASSUME=1

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
    command ps "$@"
  }
  export -f ps

  # Create temp file for ps output
  PS_OUTPUT_FILE="$(mktemp)"
  export PS_OUTPUT_FILE
}

teardown() {
  rm -f "$PS_OUTPUT_FILE"
}

# awst_list tests

@test "awst_list shows help with --help" {
  source ./lib/commands/awst_list.sh
  
  run awst_list --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: awst list" ]]
}

@test "awst_list shows no sessions when none found" {
  # Empty ps output
  echo "" > "$PS_OUTPUT_FILE"
  
  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "none found" ]]
}

@test "awst_list parses shell session" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-abc123
EOF

  # Stub aws to avoid actual EC2 calls
  aws() { return 1; }
  export -f aws

  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "12345" ]]
  [[ "$output" =~ "Interactive Shell" ]]
  [[ "$output" =~ "i-abc123" ]]
}

@test "awst_list parses port forwarding to remote host" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartPortForwardingSessionToRemoteHost --target i-abc123 --parameters {"host":["rds.example.com"],"localPortNumber":["5432"],"portNumber":["5432"]}
EOF

  aws() { return 1; }
  export -f aws

  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "12345" ]]
  [[ "$output" =~ "Port: 5432" ]]
  [[ "$output" =~ "rds.example.com" ]]
  [[ "$output" =~ "i-abc123" ]]
}

@test "awst_list extracts target from --target flag" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-xyz789
EOF

  aws() { return 1; }
  export -f aws

  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "i-xyz789" ]]
}

@test "awst_list extracts target from JSON when no --target flag" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {"TargetId":"i-json123"} us-east-1 StartSession
EOF

  aws() { return 1; }
  export -f aws

  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "i-json123" ]]
}

@test "awst_list resolves instance names via EC2" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-abc123
EOF

  # Mock aws to return instance name
  aws() {
    if [[ "$1" == "ec2" && "$2" == "describe-instances" ]]; then
      echo "my-web-server"
      return 0
    fi
    return 1
  }
  export -f aws

  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "my-web-server" ]]
  [[ "$output" =~ "i-abc123" ]]
}

@test "awst_list handles multiple sessions" {
  cat > "$PS_OUTPUT_FILE" <<'EOF'
user     12345  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-aaa111
user     12346  0.0  0.0  12345  1234 pts/0    S+   10:00   0:00 session-manager-plugin {} us-east-1 StartSession --target i-bbb222
EOF

  aws() { return 1; }
  export -f aws

  source ./lib/commands/awst_list.sh
  
  run awst_list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "12345" ]]
  [[ "$output" =~ "12346" ]]
  [[ "$output" =~ "i-aaa111" ]]
  [[ "$output" =~ "i-bbb222" ]]
}
