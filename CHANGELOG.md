# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Config-based Port Forwarding**: Profile field is now optional in connection configs
  - When profile is omitted, uses current `AWS_PROFILE` or prompts for selection
  - When profile is specified, validates and uses that profile as before
  - Improves workflow when working within a single AWS profile

## [1.0.0] - 2025-12-20

### Added
- **Core Commands**
  - `ssm connect` - Start SSM shell sessions or port forwarding to EC2 instances
  - `ssm exec` - Execute commands on multiple instances simultaneously with real-time polling
  - `ssm list` - List active SSM sessions on the current host
  - `ssm kill` - Terminate active SSM sessions

- **Authentication**
  - Integration with [Granted](https://granted.dev) for AWS SSO authentication
  - Support for AWS profiles and regions via CLI flags
  - Automatic credential validation

- **Interactive Menus**
  - fzf-powered interactive selection with fallback to bash `select`
  - Single and multi-instance selection
  - Cancel support with consistent error code (130)
  - Non-interactive mode support for automation

- **Saved Commands**
  - Command library system with user and system commands
  - Default commands installed from `examples/commands.config`
  - User custom commands in `~/.config/aws-ssm-tools/commands.user.config`
  - Environment variable override support (`AWS_SSM_COMMAND_FILE`)

- **Port Forwarding**
  - Config-based port forwarding with INI-style configuration
  - Interactive config section selection
  - Custom config file support

- **Instance Management**
  - EC2 instance listing with Name tag resolution
  - Instance caching (30s TTL) to reduce API calls
  - Support for both instance IDs and instance names
  - Semicolon-separated multi-instance targeting

- **Command Execution Features**
  - Real-time command status polling
  - Automatic command completion detection
  - Stdout/stderr output display from all instances
  - Failed command output highlighting
  - Configurable polling intervals

- **Installation & Updates**
  - One-line curl installer
  - Version pinning support (install specific versions)
  - Update script with version comparison
  - Automatic default commands installation

- **Version Management**
  - Semantic versioning (SemVer)
  - `--version` flag to display current version
  - Automated release script with GitHub integration
  - Task commands for releases: `task release`, `task release:patch`, etc.

- **Logging System**
  - Structured logging with multiple levels (DEBUG, INFO, WARN, ERROR)
  - Colored output with timestamps
  - File logging support
  - Environment variable configuration

- **Common Flags**
  - `--dry-run` - Show commands without executing
  - `--profile` - AWS profile selection
  - `--region` - AWS region selection
  - `--yes` - Non-interactive mode
  - `--help` - Command help

- **Testing**
  - 155 comprehensive unit tests using BATS
  - Test guard pattern for stubbing external dependencies
  - Menu system tests with fzf mocking
  - Command execution tests with SSM mocking
  - CI integration with `task ci`

- **Documentation**
  - Comprehensive README with examples
  - RELEASE.md with full release process documentation
  - QUICKSTART-RELEASES.md for quick reference
  - WARP.md for AI assistant guidance
  - Inline help for all commands

### Technical Details
- **Architecture**: Layered architecture with core, AWS, menu, and command layers
- **Dependencies**: bash 4.0+, AWS CLI, Granted (assume), session-manager-plugin
- **Optional**: fzf for enhanced menus, shellcheck for linting
- **Install Location**: `~/.local/share/aws-ssm-tools` with symlinks in `~/.local/bin`

### Compatibility
- Tested on Linux (EndeavourOS, Ubuntu, Amazon Linux)
- macOS support expected but not extensively tested
- Requires bash 4.0 or later

[Unreleased]: https://github.com/kedwards/aws-ssm-tools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kedwards/aws-ssm-tools/releases/tag/v1.0.0
