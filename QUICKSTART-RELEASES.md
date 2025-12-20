# Quick Start: Release Management

## Prerequisites

Install GitHub CLI and authenticate:
```bash
# Install (if needed)
# macOS: brew install gh
# Linux: https://cli.github.com/

# Authenticate
gh auth login
```

## Creating Your First Release

1. **Check current version:**
   ```bash
   task version
   # or
   cat VERSION
   ```

2. **Make sure everything is clean:**
   ```bash
   git status  # Should be clean
   task ci     # Tests should pass
   ```

3. **Create the release:**
   ```bash
   task release
   ```
   
   Follow the interactive prompts:
   - Choose version bump type (patch/minor/major)
   - Confirm the release
   - Script will automatically:
     - Run tests
     - Update VERSION file
     - Create git tag
     - Push to GitHub
     - Create GitHub release

## Common Release Commands

```bash
# Interactive release (recommended for first time)
task release

# Quick patch release (bug fixes: 0.1.0 -> 0.1.1)
task release:patch

# Minor release (new features: 0.1.0 -> 0.2.0)
task release:minor

# Major release (breaking changes: 0.1.0 -> 1.0.0)
task release:major
```

## After Creating a Release

1. **View the release on GitHub:**
   ```bash
   gh release list
   gh release view v0.1.0
   ```

2. **Team members can install it:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash -s v0.1.0
   ```

3. **Or update to it:**
   ```bash
   ~/.local/share/aws-ssm-tools/update.sh v0.1.0
   ```

## Version Semantics

- **Patch** (0.0.X) - Bug fixes, no new features
- **Minor** (0.X.0) - New features, backwards compatible  
- **Major** (X.0.0) - Breaking changes

## Troubleshooting

**Tests fail during release?**
```bash
# Fix issues first
task ci

# Try release again
task release
```

**Need to delete a bad release?**
```bash
gh release delete v0.1.0
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
```

## Full Documentation

See [RELEASE.md](RELEASE.md) for complete documentation including:
- Hotfix workflow
- Manual release recovery
- Team workflows
- Advanced scenarios
