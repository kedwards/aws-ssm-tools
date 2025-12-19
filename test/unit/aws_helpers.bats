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

  # Stub dependencies that aws.sh sources
  aws_get_all_running_instances() { :; }
  aws_expand_instances() { :; }
  aws_ssm_start_shell() { :; }
  aws_ssm_start_port_forward() { :; }
  menu_select_one() { :; }
  export -f aws_get_all_running_instances aws_expand_instances
  export -f aws_ssm_start_shell aws_ssm_start_port_forward menu_select_one

  # Set ROOT_DIR for sourcing
  ROOT_DIR="$(pwd)"
  export ROOT_DIR

  # Create temp directory for mock AWS config
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  
  # Create mock .aws directory
  mkdir -p "$HOME/.aws"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_HOME"
}

@test "aws_list_profiles returns empty when no config file" {
  source ./lib/core/aws.sh
  
  result=$(aws_list_profiles)
  [ -z "$result" ]
}

@test "aws_list_profiles parses single profile" {
  cat > "$HOME/.aws/config" <<EOF
[profile dev]
region = us-east-1
EOF

  source ./lib/core/aws.sh
  
  result=$(aws_list_profiles)
  [ "$result" = "dev" ]
}

@test "aws_list_profiles parses multiple profiles" {
  cat > "$HOME/.aws/config" <<EOF
[profile dev]
region = us-east-1

[profile staging]
region = us-west-2

[profile prod]
region = us-east-1
EOF

  source ./lib/core/aws.sh
  
  mapfile -t profiles < <(aws_list_profiles)
  [ "${#profiles[@]}" -eq 3 ]
  [ "${profiles[0]}" = "dev" ]
  [ "${profiles[1]}" = "staging" ]
  [ "${profiles[2]}" = "prod" ]
}

@test "aws_list_profiles handles default profile" {
  cat > "$HOME/.aws/config" <<EOF
[default]
region = us-east-1

[profile dev]
region = us-west-2
EOF

  source ./lib/core/aws.sh
  
  mapfile -t profiles < <(aws_list_profiles)
  [ "${#profiles[@]}" -eq 2 ]
  [ "${profiles[0]}" = "default" ]
  [ "${profiles[1]}" = "dev" ]
}

@test "aws_list_profiles ignores comments and blank lines" {
  cat > "$HOME/.aws/config" <<EOF
# This is a comment
[profile dev]
region = us-east-1

# Another comment
[profile prod]
region = us-west-2
EOF

  source ./lib/core/aws.sh
  
  mapfile -t profiles < <(aws_list_profiles)
  [ "${#profiles[@]}" -eq 2 ]
  [ "${profiles[0]}" = "dev" ]
  [ "${profiles[1]}" = "prod" ]
}
