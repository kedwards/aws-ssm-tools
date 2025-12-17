#!/usr/bin/env bash

MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Core dependency
source "$MENU_DIR/../core/interaction.sh"

# Shared helpers
source "$MENU_DIR/_common.sh"

# Public APIs
source "$MENU_DIR/select_one.sh"
source "$MENU_DIR/select_many.sh"
