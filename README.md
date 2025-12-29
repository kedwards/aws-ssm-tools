# AWS SSM Tools

A Bash-based CLI tool for managing AWS Systems Manager (SSM) sessions with interactive menus and multi-instance command execution.

## Features

- 🔐 **AWS Authentication** - Integration with [Granted](https://granted.dev) for AWS SSO
- 🖥️ **Interactive Menus** - fzf-powered selection with fallback to bash `select`
- 🚀 **Shell Sessions** - Quick SSM session connections to EC2 instances
- ⚡ **Command Execution** - Run commands on multiple instances simultaneously
- 📋 **Session Management** - List and terminate active SSM sessions
- 🔌 **Port Forwarding** - Config-based port forwarding to instances
- 💾 **Saved Commands** - Reusable command library
- ✅ **100+ Tests** - Comprehensive test coverage with BATS

## Installation

### Latest Release (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash
```

### Specific Version

```bash
# Install specific version
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash -s v0.1.0
```

### From Source (Development)

```bash
git clone https://github.com/kedwards/aws-ssm-tools
cd aws-ssm-tools
./install.sh
```

This installs to `~/.local/share/aws-ssm-tools` with symlinks in `~/.local/bin`.

### Check Version

```bash
ssm --version
```

## Prerequisites

**Required:**
- `bash` (4.0+)
- `aws` CLI
- [`assume` (Granted)](https://granted.dev) - for AWS SSO authentication
- `session-manager-plugin` - for SSM connections

**Optional:**
- `fzf` - for enhanced interactive menus (falls back to bash `select`)

## Quick Start

### 1. Authentication

```bash
# Authenticate
assume prod -r us-east-1

# Verify authentication
aws sts get-caller-identity
```

**Note:** Due to shell limitations, `assume` must be run directly in your terminal to export credentials properly.

### 2. Connect to an Instance

```bash
# Interactive selection
ssm connect

# Direct connection
ssm connect -p prod -r us-east-1

# Config-based port forwarding
ssm connect --config
```

### 3. Execute Commands

```bash
# Interactive: select command and instances
ssm exec

# Explicit command on multiple instances
ssm exec -c "uptime" -i "web-server;db-server"

# Use saved command
ssm exec -c disk-usage -i prod-app
```

### 4. Manage Sessions

```bash
# List active sessions
ssm list

# Terminate sessions
ssm kill
```

## Commands

### `ssm connect`
Start an SSM shell session or port forwarding to an EC2 instance.

**Options:**
- `-p, --profile` - AWS profile
- `-r, --region` - AWS region
- `-c, --config` - Use config-based port forwarding
- `-f, --file` - Config file path (default: `~/.ssmf.cfg`)
- `-n, --dry-run` - Show commands without executing

**Examples:**
```bash
# Interactive instance selection
ssm connect -p prod

# Config-based port forwarding
ssm connect --config -f ~/.ports.cfg
```

### `ssm exec`
Execute a command on one or more EC2 instances via SSM.

**Options:**
- `-c <command>` - Command to execute
- `-p, --profile` - AWS profile
- `-r, --region` - AWS region
- `-i <instances>` - Semicolon-separated instance names/IDs
- `-n, --dry-run` - Show commands without executing
- `-y, --yes` - Non-interactive mode

**Examples:**
```bash
# Interactive command and instance selection
ssm exec

# Explicit command on multiple instances
ssm exec -c "df -h" -i "web1;web2;web3"

# Use saved command
ssm exec -c system-uptime -p prod
```

### `ssm list`
List active SSM sessions on the current host.

**Example:**
```bash
ssm list
```

### `ssm kill`
Terminate active SSM sessions.

**Examples:**
```bash
# Interactive selection
ssm kill

# Kill all sessions (with confirmation)
ssm kill --all
```

## Configuration

### Saved Commands

Default commands are installed to `~/.local/share/aws-ssm-tools/commands.config` from `examples/commands.config`.

You can override or add commands in these locations (checked in order):
1. `~/.local/share/aws-ssm-tools/commands.config` (default commands, updated on install/update)
2. `~/.config/aws-ssm-tools/commands.user.config` (your custom commands, never overwritten)
3. Custom path via `$AWS_SSM_COMMAND_FILE` environment variable

**Format:**
```
# Command format: NAME|Description|Command to execute
disk-usage|Check disk usage|df -h
memory-info|Display memory information|free -h
docker-status|Check Docker containers|docker ps -a
```

**Adding Custom Commands:**
```bash
# Create user commands file (will never be overwritten by updates)
mkdir -p ~/.config/aws-ssm-tools
cat > ~/.config/aws-ssm-tools/commands.user.config <<'EOF'
# My custom commands
my-check|Custom health check|curl http://localhost:8080/health
restart-app|Restart application|systemctl restart myapp
EOF
```

### Port Forwarding Config

Create `~/.ssmf.cfg` with INI-style sections:

```ini
[postgres-prod]
profile = production
region = us-east-1
name = postgres-primary
host = localhost
port = 5432
local_port = 5432

[redis-staging]
profile = staging
region = us-west-2
name = redis-cache
host = localhost
port = 6379
local_port = 6379
```

Then use:
```bash
ssm connect --config
```

## Environment Variables

### Logging
- `AWS_LOG_LEVEL` - DEBUG|INFO|WARN|ERROR (default: INFO)
- `AWS_LOG_COLOR` - 1=enabled, 0=disabled (default: 1)
- `AWS_LOG_TIMESTAMP` - 1=show, 0=hide (default: 1)
- `AWS_LOG_FILE` - Log file path (default: none)

### Behavior
- `MENU_NON_INTERACTIVE` - Disable interactive prompts
- `MENU_NO_FZF` - Force bash `select` instead of fzf
- `AWS_SSM_COMMAND_FILE` - Custom commands file path

## Updating

Update to the latest release:

```bash
~/.local/share/aws-ssm-tools/update.sh
```

Update to a specific version:

```bash
~/.local/share/aws-ssm-tools/update.sh v0.1.0
```

Update to development version (main branch):

```bash
~/.local/share/aws-ssm-tools/update.sh main
```

## PATH Configuration

Ensure `~/.local/bin` is in your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Development

### Running Tests

```bash
# All unit tests
task test

# Or use bats directly
bats test/unit/

# Run specific test file
bats test/unit/ssm_exec.bats

# Run specific test
bats test/unit/ssm_exec.bats -f "polls for command completion"
```

### Linting

```bash
task lint

# Or check specific file
shellcheck lib/core/logging.sh
```

### CI

```bash
# Run all checks (lint + unit tests)
task ci
```

### Releases

For maintainers creating releases:

```bash
# Show current version
task version

# Create a new release interactively
task release

# Or create specific release types
task release:patch   # 0.1.0 -> 0.1.1 (bug fixes)
task release:minor   # 0.1.0 -> 0.2.0 (new features)
task release:major   # 0.1.0 -> 1.0.0 (breaking changes)
```

See [RELEASE.md](RELEASE.md) for detailed release management documentation.

## Troubleshooting

### "No AWS credentials found"

Run `assume` directly:
```bash
assume your-profile -r us-east-1
```

### "session-manager-plugin not found"

Install the Session Manager plugin:
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

### fzf not working

Install fzf for better menus, or the tool will fall back to bash `select`:
```bash
# macOS
brew install fzf

# Ubuntu/Debian
apt install fzf

# Arch
pacman -S fzf
```

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please:
1. Run tests: `task test`
2. Run linter: `task lint`
3. Follow existing code style
4. Add tests for new features

## Credits

Built with:
- [Granted](https://granted.dev) - AWS SSO authentication
- [BATS](https://github.com/bats-core/bats-core) - Bash testing framework
- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
