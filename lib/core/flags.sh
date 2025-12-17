#!/usr/bin/env bash

# global defaults 
DRY_RUN=false
SHOW_HELP=false
CONFIG_MODE=false
ASSUME_YES=false
CONFIG_FILE=""
PROFILE=""
REGION=""

POSITIONAL=()

parse_common_flags() {
  POSITIONAL=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -c|--config)
        CONFIG_MODE=true
        shift
        ;;
      -f|--file)
        CONFIG_FILE="$2"
        shift 2
        ;;
      -p|--profile)
        PROFILE="$2"
        shift 2
        ;;
      -r|--region)
        REGION="$2"
        shift 2
        ;;
      -h|--help)
        SHOW_HELP=true
        shift
        ;;
      -y|--yes|--assume-yes)
        ASSUME_YES=1
        MENU_NON_INTERACTIVE=1
        MENU_ASSUME_FIRST=1
        shift
        ;;
      --)
        shift
        POSITIONAL+=("$@")
        break
        ;;
      -*)
        # unknown flags are passed through
        POSITIONAL+=("$1")
        shift
        ;;
      *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
  done

  return 0
}
