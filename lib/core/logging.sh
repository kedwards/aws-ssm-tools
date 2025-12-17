#!/usr/bin/env bash
# Only set errexit if not in a test environment
if [[ -z "${BATS_TEST_DIRNAME:-}" ]]; then
  set -euo pipefail
else
  set -uo pipefail
fi

# Logging configuration
: "${AWS_LOG_LEVEL:=INFO}"            # DEBUG | INFO | WARN | ERROR
: "${AWS_LOG_TIMESTAMP:=1}"           # 1 = show timestamps, 0 = no timestamps
: "${AWS_LOG_COLOR:=1}"               # 1 = enable (tty only)
: "${AWS_LOG_FILE:=}"                 # empty = disabled
: "${AWS_LOG_FILE_MAX_SIZE:=1048576}" # 1MB
: "${AWS_LOG_FILE_ROTATE:=5}"         # number of rotated files

_color_enabled() {
  [[ "${AWS_LOG_COLOR:-1}" == "1" ]] &&
  [[ -t 2 ]] &&
  [[ -z "${NO_COLOR:-}" ]] &&
  [[ "${TERM:-}" != "dumb" ]]
}

if _color_enabled; then
  CLR_RESET=$'\e[0m'
  CLR_DEBUG=$'\e[36m'   # cyan
  CLR_INFO=$'\e[32m'    # green
  CLR_WARN=$'\e[33m'    # yellow
  CLR_ERROR=$'\e[31m'   # red
  CLR_SUCCESS=$'\e[34m'  # blue
else
  CLR_RESET='' CLR_DEBUG='' CLR_INFO='' CLR_WARN='' CLR_ERROR='' CLR_SUCCESS=''
fi

_log_level_num() {
  case "${1^^}" in
    DEBUG)   echo 10 ;;
    INFO)    echo 20 ;;
    SUCCESS) echo 25 ;;
    WARN)    echo 30 ;;
    ERROR)   echo 40 ;;
    FATAL)   echo 50 ;;
    *)       echo 20 ;;
  esac
}

_log_should_print() {
  [[ $(_log_level_num "$1") -ge $(_log_level_num "${AWS_LOG_LEVEL:-INFO}") ]]
}

_log_timestamp() {
  if [[ "$AWS_LOG_TIMESTAMP" == "1" ]]; then
    printf '[%s] ' "$(date '+%Y-%m-%d %H:%M:%S')"
  fi
}

_log_rotate_if_needed() {
  [[ -z "$AWS_LOG_FILE" || ! -f "$AWS_LOG_FILE" ]] && return 0

  local size
  size=$(stat -c '%s' "$AWS_LOG_FILE" 2>/dev/null || echo 0)
  (( size < AWS_LOG_FILE_MAX_SIZE )) && return 0

  for ((i=AWS_LOG_FILE_ROTATE; i>1; i--)); do
    [[ -f "$AWS_LOG_FILE.$((i-1))" ]] &&
      mv "$AWS_LOG_FILE.$((i-1))" "$AWS_LOG_FILE.$i"
  done

  mv "$AWS_LOG_FILE" "$AWS_LOG_FILE.1"
  : >"$AWS_LOG_FILE"
}

_log_to_file() {
  [[ -z "$AWS_LOG_FILE" ]] && return 0
  _log_rotate_if_needed
  printf '%s\n' "$1" >>"$AWS_LOG_FILE"
}

log() {
  local level="$1"; shift
  _log_should_print "$level" || return 0

  local ts msg color
  ts="$(_log_timestamp)"

  case "$level" in
    DEBUG)   color="$CLR_DEBUG" ;;
    INFO)    color="$CLR_INFO" ;;
    SUCCESS) color="$CLR_SUCCESS" ;;
    WARN)    color="$CLR_WARN" ;;
    ERROR|FATAL) color="$CLR_ERROR" ;;
    *) color="" ;;
  esac

  msg="${ts}[${level}] $*"

  printf '%s%s[%s]%s %s\n' \
    "$ts" \
    "$color" \
    "$level" \
    "$CLR_RESET" \
    "$*" >&2 || true

  _log_to_file "$msg"

  [[ "$level" == "FATAL" ]] && exit 1
  return 0
}

log_debug()   { log DEBUG   "$@"; }
log_info()    { log INFO    "$@"; }
log_success() { log SUCCESS "$@"; }
log_warn()    { log WARN    "$@"; }
log_error()   { log ERROR   "$@"; }
log_fatal()   { log FATAL   "$@"; }

# trap ERR handler (stack traces)
log_stacktrace() {
  local i
  log_error "Command failed (exit=$?)"
  for ((i=1; i<${#FUNCNAME[@]}; i++)); do
    log_error "  at ${FUNCNAME[$i]} (${BASH_SOURCE[$i]}:${BASH_LINENO[$((i-1))]})"
  done
}

# Only trap ERR if not in a test environment
if [[ -z "${BATS_TEST_DIRNAME:-}" ]]; then
  trap 'log_stacktrace' ERR
fi
