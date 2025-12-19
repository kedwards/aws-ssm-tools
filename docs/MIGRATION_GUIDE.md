# Migration Guide: Main → Enhanced Version

**Version:** 2.0 (Rewrite with Rich CLI)  
**Date:** December 12, 2025

## Overview

The enhanced version combines the best of both worlds:
- ✨ Modern modular architecture
- 🚀 Powerful rich CLI from main branch
- 🔄 **100% backward compatible**
- 🎨 Enhanced logging with colors
- 🔐 Auto-validating SSO

## TL;DR - Do I Need to Change Anything?

**No!** All your existing scripts and commands will continue to work exactly as before.

## What's Changed

### Architecture (Internal - You Don't Need to Worry About This)
- **Before:** Single 25KB `aws_ssm.sh` file
- **After:** Modular libraries (common.sh, exec.sh, connect.sh, etc.)
- **Impact:** Easier for developers to maintain, zero impact on users

### New Features Available

#### 1. Unified CLI (Optional - New Way)
You can now use a modern unified interface:

```bash
# Old way (still works!)
aws-ssm-connect my-server
aws-ssm-exec "uptime" my-server

# New way (optional)
ssm connect my-server
ssm exec -c "uptime" -i my-server
```

#### 2. Enhanced Logging
Colored output with timestamps (can be disabled):

```bash
# Default: colors + timestamps
ssmx -c 'uptime' -e prod -i web

# Disable colors
AWS_LOG_COLOR=off ssmx -c 'uptime' -e prod -i web

# Disable timestamps  
AWS_LOG_TIMESTAMP=0 ssmx -c 'uptime' -e prod -i web
```

#### 3. Auto-Validating SSO
No more "ExpiredToken" errors! The tool now:
1. Validates your SSO token before making AWS calls
2. Automatically refreshes if expired
3. Falls back to `aws sso login` if needed

## What Hasn't Changed

### All CLI Patterns Still Work ✅

```bash
# Pattern 1: Full specification
ssmx -c 'ls -lF; uptime' -e how -i Report

# Pattern 2: Profile with region
ssmx -c 'ls -lF; uptime' -e how:us-west-2 -i Report

# Pattern 3: Separate region flag
ssmx -c 'ls -lF; uptime' -e how -r us-west-2 -i Report

# Pattern 4: Multiple instances
ssmx -c 'ls -lF; uptime' -e how -i 'Report;Singleton'

# Pattern 5-8: All interactive modes
ssmx -c 'ls -lF; uptime' -e how
ssmx -e how
ssmx -c 'ls -lF; uptime'
ssmx
```

### All Commands Work ✅

```bash
aws-ssm-connect [instance]
aws-ssm-exec '<command>' [instances...]
aws-ssm-list
aws-ssm-kill
aws-instances
aws-env-run '<command>' [envs...]
```

### ssmx Alias Works ✅

```bash
# If you have scripts using ssmx, they still work
ssmx -c 'systemctl status myapp' -e prod -i web-01
```

## Migration Scenarios

### Scenario 1: "I just want to update"

```bash
# Update to enhanced version
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash

# Or if you have aws-ssm-tools-update
aws-ssm-tools-update
```

**Result:** Everything works exactly as before + you get new features automatically.

### Scenario 2: "I want to try the new unified CLI"

You can use both styles interchangeably:

```bash
# Old style (you're used to this)
ssmx -c 'uptime' -e prod -i web

# New style (equivalent)
ssm exec -c 'uptime' -e prod -i web
```

Pick whichever you prefer - both work!

### Scenario 3: "I have automation scripts"

**No changes needed!** Your scripts will continue working:

```bash
#!/bin/bash
# This script still works exactly as before
export AWS_PROFILE=production
ssmx -c 'systemctl restart myservice' -i 'web-01;web-02;web-03'
```

### Scenario 4: "I use saved commands"

Saved commands work exactly the same way:

**Location priority (unchanged):**
1. `$AWS_SSM_COMMAND_FILE` (if set)
2. `~/.config/aws-ssm-tools/commands.user.config`
3. `~/.local/share/aws-ssm-tools/commands.config`

**Format (unchanged):**
```
COMMAND_NAME|Description|Command to execute
disk-usage|Check disk usage|df -h
```

**Usage (unchanged):**
```bash
ssmx              # Select command interactively
ssmx -e prod      # Select command, use prod profile
```

## New Environment Variables

These are **optional** - everything works without them:

```bash
# Logging control
export AWS_LOG_LEVEL=DEBUG          # DEBUG, INFO, WARN, ERROR (default: INFO)
export AWS_LOG_TIMESTAMP=1          # 1=show timestamps, 0=hide (default: 1)
export AWS_LOG_COLOR=auto           # auto, on, off (default: auto)

# Granted SSO control (these were available before)
export GRANTED_NO_BROWSER=true      # Don't open browser
export GRANTED_DISABLE_PROMPTS=true # No interactive prompts
```

## Troubleshooting

### "My script stopped working!"

This shouldn't happen, but if it does:

1. Check that the command still works manually:
   ```bash
   ssmx -c 'echo test' -e your-profile -i your-instance
   ```

2. Check for typos in your script

3. Enable debug logging:
   ```bash
   AWS_LOG_LEVEL=DEBUG your-script.sh
   ```

4. Compare with main branch:
   ```bash
   # The main branch is still available
   cd /path/to/aws-ssm-tools
   ./main/bin/aws-ssm-exec --help
   ```

### "I want the old version back"

The main branch is still available and unchanged:

```bash
# Install from main branch specifically
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash
```

### "The new colored output breaks my log parser"

Disable colors:

```bash
# In your script
export AWS_LOG_COLOR=off
ssmx -c 'command' -e profile -i instance

# Or one-time
AWS_LOG_COLOR=off ssmx -c 'command' -e profile -i instance
```

### "I don't see the ssmx command"

Reinstall or create the symlink manually:

```bash
# Create symlink
ln -sf ~/.local/bin/aws-ssm-exec ~/.local/bin/ssmx

# Or reinstall
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash
```

## Feature Comparison

| Feature | Main Branch | Enhanced Version |
|---------|-------------|------------------|
| CLI patterns | ✅ All 8 patterns | ✅ All 8 patterns |
| ssmx command | ✅ Yes | ✅ Yes |
| Profile:region | ✅ Yes | ✅ Yes |
| Multiple instances | ✅ Yes | ✅ Yes |
| Saved commands | ✅ Yes | ✅ Yes |
| Port forwarding | ✅ Yes | ✅ Yes |
| **Unified CLI** | ❌ No | ✅ **New!** |
| **Colored logs** | ❌ No | ✅ **New!** |
| **SSO auto-refresh** | ❌ No | ✅ **New!** |
| **Log levels** | ⚠️ Basic | ✅ **Enhanced** |
| **Modular code** | ❌ No | ✅ **New!** |

## Testing Your Migration

Run these commands to verify everything works:

```bash
# Test help
ssmx --help
ssm exec --help

# Test command parsing (won't actually run without AWS)
ssmx -c 'echo test' -e profile -i instance --help

# Test profile:region syntax
ssmx -c 'test' -e prod:us-west-2 -i instance --help

# Test multiple instances
ssmx -c 'test' -e prod -i 'inst1;inst2;inst3' --help

# Test unified CLI
ssm exec -c 'test' -e prod -i instance --help
```

If all these show the usage/help text, you're good!

## Best Practices

### For New Scripts
Consider using the unified CLI for new scripts:

```bash
#!/bin/bash
# Modern style
ssm exec -c 'systemctl status myapp' -e prod -i web-server
```

### For Existing Scripts
No need to change anything:

```bash
#!/bin/bash
# This still works perfectly
ssmx -c 'systemctl status myapp' -e prod -i web-server
```

### For Interactive Use
Use whichever style you prefer:

```bash
# Quick and familiar
ssmx -c 'uptime' -e prod -i web

# More explicit and modern
ssm exec -c 'uptime' -e prod -i web
```

## Getting Help

### View Documentation
```bash
ssmx --help
ssm exec --help
ssm connect --help
```

### Enable Debug Mode
```bash
AWS_LOG_LEVEL=DEBUG ssmx -c 'command' -e profile -i instance
```

### Check Version
```bash
head -1 ~/.local/share/aws-ssm-tools/README.md
```

## Rollback Plan

If you need to rollback (though this shouldn't be necessary):

```bash
# Option 1: Reinstall from specific branch
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash

# Option 2: Manual rollback
cd /path/to/aws-ssm-tools
rsync -a main/ ~/.local/share/aws-ssm-tools/
```

## Summary

### ✅ What You Need to Do
**Nothing!** Just update and keep using it the same way.

### ✨ What You Can Do (Optional)
- Try the new `ssm` unified CLI
- Enjoy colored logs
- Benefit from auto-refreshing SSO
- Use enhanced debug logging

### 🔄 What Stays the Same
- All CLI patterns
- All commands
- All saved commands
- All environment variables
- All configuration files
- Exit codes and output format

## Questions?

**Q: Will my existing automation break?**  
A: No, 100% backward compatible.

**Q: Do I need to update my saved commands?**  
A: No, same format.

**Q: Can I use both CLI styles?**  
A: Yes! Mix and match as you like.

**Q: What if I prefer no colors?**  
A: `export AWS_LOG_COLOR=off`

**Q: Is SSO required?**  
A: No, if you use IAM credentials or instance profiles, it works the same.

---

**Ready to migrate?**

```bash
curl -sSL https://raw.githubusercontent.com/kedwards/aws-ssm-tools/main/install.sh | bash
```

That's it! Enjoy the enhanced version! 🎉
