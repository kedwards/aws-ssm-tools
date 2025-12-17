#!/usr/bin/env bash

# Prevent real implementations from overriding test stubs
guard_function_override() {
  local fn="$1"
  if declare -F "$fn" >/dev/null; then
    return 0
  fi
  return 1
}
