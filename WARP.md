# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is `aws-ssm-tools`, a Bash-based CLI tool for managing AWS Systems Manager (SSM) sessions. The tool provides interactive menus (with fzf support) for connecting to EC2 instances via SSM and managing port forwarding through configuration files.

## Development Commands

### Testing
```bash
# Run unit tests (no AWS authentication required)
task test

# Run integration tests (requires AWS authentication)
task test:integration

# Run single test file
bats test/unit/menu_select_one.bats

# Run specific test
bats test/unit/menu_select_one.bats -f "cancel returns error code 130"
```

### Linting
```bash
# Run shellcheck on main menu module
task lint

# Check specific file
shellcheck lib/core/logging.sh
```

### CI
```bash
# Run all checks (lint + unit tests)
task ci
```

### Installation
```bash
# Install to ~/.local/share/aws-ssm-tools with symlinks in ~/.local/bin
./install.sh

# Update existing installation
./update.sh
```

## Architecture

### Code Organization

The codebase follows a layered architecture with clear separation of concerns:

**Core Layer** (`lib/core/`)
- `logging.sh` - Structured logging with levels, colors, timestamps, and file rotation
- `flags.sh` - Common flag parsing (--dry-run, --profile, --region, --yes, --config)
- `interaction.sh` - Interactive mode guards and browser opening
- `aws_auth.sh` - AWS authentication via Granted (SSO) with validation
- `aws.sh` - AWS CLI utilities
- `tty.sh` - TTY detection
- `test_guard.sh` - Function override protection for tests

**AWS Layer** (`lib/aws/`)
- `ec2.sh` - EC2 instance listing with caching (30s TTL), Name tag resolution
- `ssm.sh` - SSM session start wrappers (shell and port forwarding)

**Menu System** (`lib/menu/`)
- `index.sh` - Entry point that loads all menu components
- `select_one.sh` - Single-item selection with fzf/fallback support
- `select_many.sh` - Multi-item selection with fzf/fallback support
- `_common.sh` - Shared menu utilities
- `backends/auto.sh` - Auto-detect fzf availability
- `backends/fzf.sh` - fzf-specific implementation
- `backends/fallback.sh` - Bash `select` fallback

**Commands** (`lib/commands/`)
- `ssm_login.sh` - Interactive AWS SSO login via Granted
- `ssm_connect.sh` - Connect to instances (shell or port-forward modes)

**Entry Point** (`bin/ssm`)
- Main dispatcher that sources all libraries and routes subcommands

### Key Architectural Patterns

**Test Guard Pattern**
Functions that interact with external systems (AWS, fzf) use `guard_function_override` to allow test stubs to take precedence. Tests define stubs before sourcing the real implementation:
```bash
# In tests
aws_ec2_select_instance() { echo "stub"; }
source ./lib/aws/ec2.sh  # Real function won't override stub
```

**Non-Interactive Mode**
The tool supports both interactive and non-interactive usage. Commands respect:
- `MENU_NON_INTERACTIVE=1` - Explicitly disable interaction
- `MENU_ASSUME_FIRST=1` - Auto-select first item in menus (used with --yes)
- `CI=true` - Detect CI environments

**Instance Caching**
EC2 instances are cached in `~/.cache/ssm/instances_${profile}_${region}.cache` with 30s TTL to reduce API calls during interactive selection.

**Error Code Convention**
- `130` - User cancelled/ESC pressed (mirrors fzf convention)
- `1` - General error

**Dry-Run Mode**
All commands support `--dry-run` which:
- Skips AWS authentication entirely
- Prints commands that would be executed
- Never makes external calls

### Testing Strategy

**Unit Tests** (`test/unit/`)
- Use BATS (Bash Automated Testing System)
- Stub all external dependencies (AWS CLI, fzf, logging)
- Set `export AWS_EC2_DISABLE_LIVE_CALLS=1` and `AWS_AUTH_DISABLE_ASSUME=1`
- Test flags, menu selection logic, command dispatch

**Integration Tests** (`test/integration/`)
- Currently empty (placeholder for future AWS integration tests)
- Would require valid AWS credentials

**Test Helpers** (`test/helpers/`)
- `bats-support/` and `bats-assert/` - BATS testing libraries
- `menu_harness.sh` - Common stubs for menu tests
- Fake `fzf` wrapper for testing menu backends

### Flag Handling

All commands inherit common flags via `parse_common_flags`:
- `-n, --dry-run` - Show commands without executing
- `-p, --profile` - AWS profile
- `-r, --region` - AWS region
- `-c, --config` - Enable config-based port forwarding
- `-f, --file` - Config file override (default: `~/.ssmf.cfg`)
- `-y, --yes` - Non-interactive mode (auto-select first option)
- `-h, --help` - Show help

### Logging

Use structured logging functions from `lib/core/logging.sh`:
```bash
log_debug "detailed info"
log_info "informational message"
log_success "operation succeeded"
log_warn "warning message"
log_error "error occurred"
log_fatal "critical error" # exits with code 1
```

Control via environment variables:
- `AWS_LOG_LEVEL` - DEBUG|INFO|WARN|ERROR (default: INFO)
- `AWS_LOG_COLOR` - 1=enabled, 0=disabled (default: 1)
- `AWS_LOG_TIMESTAMP` - 1=show, 0=hide (default: 1)
- `AWS_LOG_FILE` - Log file path (default: none)

### Menu System Usage

The menu system provides consistent interactive selection with automatic fzf detection:

```bash
# Single selection
menu_select_one "Select instance" "Header text" result_var "${array[@]}"
echo "Selected: $result_var"

# Multi-selection
menu_select_many "Select instances" "Header" results "${array[@]}"
# results contains newline-separated selections
```

Menu behavior:
- Automatically uses fzf if available (unless `MENU_NO_FZF=1`)
- Falls back to Bash `select` built-in
- Returns 130 on cancel/ESC
- Respects non-interactive flags

## AWS Configuration

The tool uses **Granted** for AWS authentication. Config-based port forwarding uses INI-style config files:

```ini
[my-db]
profile = prod
region = us-east-1
name = postgres-primary
host = localhost
port = 5432
local_port = 5432
url = http://localhost:5432
```

Config sections can be selected interactively via `ssm connect --config`.

## Dependencies

**Required:**
- `bash` (4.0+)
- `aws` CLI
- `assume` (Granted) - for AWS SSO authentication
- BATS - for running tests

**Optional:**
- `fzf` - for enhanced interactive menus (falls back to Bash `select`)
- `shellcheck` - for linting

## Current Branch Context

Working on branch: `feature/arch-split`
This appears to be related to architectural refactoring or code organization improvements.
