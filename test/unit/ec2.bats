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
}

# aws_expand_instances tests

@test "aws_expand_instances returns instance-id when given instance-id" {
  source ./lib/aws/ec2.sh
  
  result=$(aws_expand_instances "i-1234567890abcdef0")
  [ "$result" = "i-1234567890abcdef0" ]
}

@test "aws_expand_instances queries AWS for name tags" {
  # Mock aws cli
  aws() {
    if [[ "$1" == "ec2" && "$2" == "describe-instances" ]]; then
      # Return mock instance IDs
      echo -e "i-111\ti-222"
      return 0
    fi
    return 1
  }
  export -f aws

  source ./lib/aws/ec2.sh
  
  result=$(aws_expand_instances "my-instance")
  # Should return newline-separated instances
  [ "$(echo "$result" | wc -l)" -eq 2 ]
  [ "$(echo "$result" | head -n1)" = "i-111" ]
  [ "$(echo "$result" | tail -n1)" = "i-222" ]
}

@test "aws_expand_instances returns empty for no matches" {
  # Mock aws cli returning nothing
  aws() {
    if [[ "$1" == "ec2" && "$2" == "describe-instances" ]]; then
      return 0
    fi
    return 1
  }
  export -f aws

  source ./lib/aws/ec2.sh
  
  result=$(aws_expand_instances "nonexistent")
  [ -z "$result" ]
}

@test "aws_expand_instances uses correct filters" {
  # Mock aws cli to verify filters
  aws() {
    if [[ "$1" == "ec2" && "$2" == "describe-instances" ]]; then
      # Verify filters are present
      local filters_found=0
      for arg in "$@"; do
        if [[ "$arg" == "--filters" ]]; then
          filters_found=1
        fi
        if [[ "$arg" =~ Name=instance-state-name,Values=running ]]; then
          filters_found=$((filters_found + 1))
        fi
        if [[ "$arg" =~ Name=tag:Name,Values= ]]; then
          filters_found=$((filters_found + 1))
        fi
      done
      
      [ "$filters_found" -eq 3 ]
      echo "i-test"
      return 0
    fi
    return 1
  }
  export -f aws

  source ./lib/aws/ec2.sh
  
  result=$(aws_expand_instances "test-name")
  [ "$result" = "i-test" ]
}
