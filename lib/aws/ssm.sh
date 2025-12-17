#!/usr/bin/env bash

aws_ssm_start_shell() {
  local instance_id="$1"
  aws ssm start-session --target "$instance_id"
}

aws_ssm_start_port_forward() {
  local instance_id="$1"
  local host="$2"
  local port="$3"
  local local_port="${4:-$port}"

  aws ssm start-session \
    --target "$instance_id" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$host\"],\"portNumber\":[\"$port\"],\"localPortNumber\":[\"$local_port\"]}"
}
