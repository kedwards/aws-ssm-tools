#!/usr/bin/env bash

awst_creds_usage() {
  cat <<EOF
Usage: awst creds <store|use>

Manage AWS credentials for the current shell.

Subcommands:
  store <env>  Export AWS credentials for <env> into the current shell
  use          Re-apply stored credentials (AK/SK/ST) as AWS_ env vars

Examples:
  eval "\$(awst creds store myenv)"
  eval "\$(awst creds use)"
EOF
}

awst_creds_store() {
  local env="${1:-}"

  if [[ -z "$env" || "$env" == "-h" || "$env" == "--help" ]]; then
    cat <<EOF
Usage: awst creds store <env>
  Exports AWS credentials for <env> into the current shell.
  Requires: assume (Granted)

Examples:
  eval "\$(awst creds store myenv)"
EOF
    return 0
  fi

  if ! command -v assume >/dev/null 2>&1; then
    log_error "'assume' (Granted) not found in PATH"
    return 1
  fi

  if [[ "${AWST_AUTH_DISABLE_ASSUME:-0}" == "1" ]]; then
    log_debug "Skipping assume (AWST_AUTH_DISABLE_ASSUME=1)"
    return 0
  fi

  local creds
  creds="$(assume "$env" --exec env | awk -F= '
    /^AWS_ACCESS_KEY_ID=/ ||
    /^AWS_SECRET_ACCESS_KEY=/ ||
    /^AWS_SESSION_TOKEN=/ ||
    /^AWS_REGION=/ {
      print "export " $1 "=\"" $2 "\""
    }
  ')"

  # Eval into current (sub)shell so vars are available for substitution below
  eval "$creds"

  cat <<EOF
$creds
export AK="$AWS_ACCESS_KEY_ID"
export SK="$AWS_SECRET_ACCESS_KEY"
export ST="$AWS_SESSION_TOKEN"
EOF
}

awst_creds_use() {
  printf 'export AWS_ACCESS_KEY_ID="%s" AWS_SECRET_ACCESS_KEY="%s" AWS_SESSION_TOKEN="%s"\n' \
    "${AK:-}" "${SK:-}" "${ST:-}"
}

awst_creds() {
  local subcmd="${1:-}"

  case "$subcmd" in
    store) shift; awst_creds_store "$@" ;;
    use)   awst_creds_use ;;
    *)     awst_creds_usage ;;
  esac
}
