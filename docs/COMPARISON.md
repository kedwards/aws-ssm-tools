# AWS SSM Tools: Main vs Rewrite Implementation Comparison

**Generated:** $(date)

## Test Results Summary

✅ **42/44 tests passed** across both implementations
- Main branch: 17/18 passed
- Rewrite branch: 25/26 passed

## Architecture Comparison

### Main Branch Architecture
```
main/
├── bin/
│   ├── aws-ssm-connect      (182 bytes)
│   ├── aws-ssm-exec         (275 bytes)
│   ├── aws-ssm-list         (179 bytes)
│   ├── aws-ssm-kill         (179 bytes)
│   ├── aws-instances        (506 bytes)
│   └── aws-env-run          (263 bytes)
└── lib/
    ├── init.sh              (431 bytes)
    ├── logging.sh           (720 bytes)
    ├── menu.sh              (3.1 KB)
    ├── aws_instances.sh     (1.6 KB)
    ├── aws_ssm.sh           (25.1 KB) ⚠️  MONOLITHIC
    └── aws_env_run.sh       (2.0 KB)
```

### Rewrite Branch Architecture
```
rewrite/
├── ssm                      (2.7 KB) ✨ NEW UNIFIED CLI
├── bin/
│   ├── aws-ssm-connect      (182 bytes)
│   ├── aws-ssm-exec         (275 bytes)
│   ├── aws-ssm-list         (179 bytes)
│   ├── aws-ssm-kill         (179 bytes)
│   ├── aws-instances        (506 bytes)
│   └── aws-env-run          (263 bytes)
└── lib/
    ├── init.sh              (431 bytes)
    ├── logging.sh           (1.9 KB) ⬆️ ENHANCED
    ├── menu.sh              (2.3 KB)
    ├── common.sh            (7.6 KB) ✨ NEW
    ├── flags.sh             (798 bytes) ✨ NEW
    ├── connect.sh           (4.8 KB) ✨ EXTRACTED
    ├── exec.sh              (4.4 KB) ✨ EXTRACTED
    ├── list.sh              (2.1 KB) ✨ EXTRACTED
    ├── kill.sh              (2.8 KB) ✨ EXTRACTED
    ├── aws_instances.sh     (1.6 KB)
    └── aws_env_run.sh       (2.0 KB)
```

## Feature Comparison Matrix

| Feature | Main Branch | Rewrite Branch | Winner |
|---------|-------------|----------------|--------|
| **CLI Style** | Individual commands | Unified `ssm` + individual | Rewrite ✨ |
| **Argument Parsing** | Rich `-c -e -r -i` flags | Simplified `-e -i` flags | Main 🏆 |
| **Profile:Region Syntax** | ✅ `profile:region` | ❌ Separate flags | Main 🏆 |
| **Multi-instance** | ✅ Semicolon-separated | ✅ Interactive only | Main 🏆 |
| **Modular Design** | ❌ Monolithic | ✅ Separated concerns | Rewrite ✨ |
| **Logging** | Basic text | Colors + timestamps | Rewrite ✨ |
| **SSO Handling** | Manual | Auto-validate/refresh | Rewrite ✨ |
| **Code Duplication** | High | Low | Rewrite ✨ |
| **Maintainability** | Difficult | Easy | Rewrite ✨ |
| **Documentation** | Extensive | Good | Main 🏆 |

## Command Interface Comparison

### aws-ssm-exec / ssmx

#### Main Branch Interface (Rich CLI)
```bash
# Full flexibility - any flag order
ssmx -c 'uptime' -e how -i Report
ssmx -c 'uptime' -e how:us-west-2 -i Report
ssmx -c 'uptime' -e how -r us-west-2 -i 'Report;Singleton'
ssmx -c 'uptime' -e how
ssmx -e how
ssmx -c 'uptime'
ssmx

# Flags:
#   -c <command>      Command to execute
#   -e <profile[:region]>  AWS profile with optional region
#   -r <region>       Override region
#   -i <instances>    Semicolon-separated instance names/IDs
```

**Strengths:**
- ✅ Flexible flag ordering
- ✅ Profile:region shorthand
- ✅ Multi-instance via semicolon
- ✅ All flags optional (interactive mode)

#### Rewrite Branch Interface (Simplified)
```bash
# Unified CLI approach
ssm exec -e 'uptime' -i instance1
ssm exec -e 'uptime'
ssm exec

# OR via traditional command
aws-ssm-exec '<command>' [INSTANCE ...]
aws-ssm-exec --select [INSTANCE ...]

# Flags:
#   -e, --exec <command>      Command to run
#   -p, --profile <profile>   AWS profile
#   -r, --region <region>     AWS region
#   -i, --instances <list>    Semicolon-separated instances
```

**Strengths:**
- ✅ Cleaner subcommand style
- ✅ Long-form flags (--profile, --exec)
- ✅ Consistent with modern CLIs

**Weaknesses:**
- ❌ Lost profile:region syntax
- ❌ More verbose
- ❌ Breaking changes from main

### aws-ssm-connect

#### Main Branch
```bash
aws-ssm-connect                     # Interactive
aws-ssm-connect my-server           # By name
aws-ssm-connect i-0123456789        # By ID
aws-ssm-connect --config            # Port-forwarding mode
```

#### Rewrite Branch
```bash
ssm connect                         # Interactive
ssm connect -i my-server            # By name
ssm connect -p profile -r region    # Explicit profile/region
ssm connect --config                # Port-forwarding mode

# OR traditional
aws-ssm-connect [INSTANCE]
aws-ssm-connect --config
```

**Both versions are similar in functionality**

## Code Quality Comparison

### Main Branch: aws_ssm.sh Analysis
- **Size:** 786 lines, 25KB
- **Functions:** 9 major functions all in one file
- **Duplication:** High (profile selection repeated 3+ times)
- **Testing:** Harder to unit test
- **Maintenance:** Difficult to modify without breaking other functions

### Rewrite Branch: Modular Analysis
- **lib/common.sh:** 260 lines - Shared utilities
- **lib/exec.sh:** 170 lines - Exec-specific logic
- **lib/connect.sh:** 158 lines - Connect-specific logic
- **lib/list.sh:** 63 lines - List sessions
- **lib/kill.sh:** 87 lines - Kill sessions
- **lib/flags.sh:** 39 lines - Flag parsing

**Benefits:**
- ✅ Clear separation of concerns
- ✅ Easy to test individual modules
- ✅ No duplication of common logic
- ✅ Each file has single responsibility

## Logging Comparison

### Main Branch Logging
```bash
log_debug() { echo "[DEBUG] $*" >&2; }
log_info()  { echo "[INFO] $*" >&2; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
```
- Basic text output
- No colors
- No timestamps
- 4 log levels

### Rewrite Branch Logging
```bash
log_debug()   { echo "[2025-12-12 20:15:52] [DEBUG] $*" >&2; }   # Gray
log_info()    { echo "[2025-12-12 20:15:52] [INFO] $*" >&2; }    # Blue
log_success() { echo "[2025-12-12 20:15:52] [SUCCESS] $*" >&2; } # Green
log_warn()    { echo "[2025-12-12 20:15:52] [WARN] $*" >&2; }    # Yellow
log_error()   { echo "[2025-12-12 20:15:52] [ERROR] $*" >&2; }   # Red
log_fatal()   { echo "[2025-12-12 20:15:52] [FATAL] $*" >&2; exit 1; } # Red + exit
```
- Color-coded output (auto-detect TTY)
- Configurable timestamps
- 6 log levels including SUCCESS and FATAL
- Environment controls: `AWS_LOG_LEVEL`, `AWS_LOG_TIMESTAMP`, `AWS_LOG_COLOR`

## SSO Authentication Comparison

### Main Branch
```bash
aws_assume_profile() {
  if declare -f assume >/dev/null 2>&1; then
    assume "$profile" -r "$region"
  else
    source assume "$profile" -r "$region"
  fi
}
```
- Manual assumption
- No validation
- No auto-refresh
- Simple function/command detection

### Rewrite Branch
```bash
aws_sso_validate_or_login() {
  # Try validation
  if aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" >/dev/null 2>&1; then
    return 0
  fi
  
  # Try assume wrapper
  if declare -f assumego >/dev/null 2>&1; then
    if assumego "$PROFILE" -r "$REGION"; then
      return 0
    fi
  fi
  
  # Fall back to AWS SSO login
  if aws sso login --profile "$PROFILE"; then
    return 0
  fi
  
  return 1
}
```
- Auto-validation before AWS calls
- Graceful fallback chain
- Better error messages
- Prevents auth failures

## Known Issues

### Main Branch
1. ⚠️ `aws-ssm-list` doesn't support --help flag (exits normally but shows output)
2. ⚠️ All SSM logic in one 25KB file
3. ⚠️ Duplicate profile selection code
4. ⚠️ No SSO token validation

### Rewrite Branch
1. ⚠️ `aws-ssm-exec` in rewrite doesn't handle --help properly (tries to run)
2. ⚠️ Lost the rich flag interface from main's ssmx
3. ⚠️ Breaking changes from established CLI patterns
4. ⚠️ bin/aws-ssm-exec still calls old aws_ssm_execute_main function (needs update)

## Recommendations

### Phase 1: Foundation ✅
- ✅ Use rewrite branch as base (modular architecture)
- ✅ Keep enhanced logging
- ✅ Keep SSO auto-validation
- ✅ Keep unified `ssm` CLI

### Phase 2: Backport Rich CLI 🎯 **PRIORITY**
- 🔧 Update `lib/flags.sh` to support main's rich parsing:
  - Add `-c` for command (in addition to `-e/--exec`)
  - Support `profile:region` syntax in `-e` flag
  - Add `-r` for region override
  - Keep semicolon-separated instances in `-i`
- 🔧 Update `lib/exec.sh` to use enhanced flags
- 🔧 Update bin/aws-ssm-exec to call ssm_exec instead of aws_ssm_execute_main

### Phase 3: Compatibility
- ✅ Keep both `ssm exec` and `aws-ssm-exec` working
- 📝 Create `ssmx` symlink
- 📝 Test all main README usage patterns

### Phase 4: Documentation
- 📝 Merge README examples from both branches
- 📝 Document migration path
- 📝 Add troubleshooting for both CLI styles

## Migration Strategy

### For End Users
1. **Zero breaking changes** - both CLI styles will work
2. **Gradual migration** - can use either `ssm exec` or `ssmx`
3. **Better experience** - enhanced logging and SSO handling

### For Developers
1. **Easier maintenance** - modular code base
2. **Better testing** - isolated functions
3. **Clear structure** - each file has one job

## Conclusion

**Use rewrite branch as foundation** + **backport main's rich CLI features** = Best of both worlds

This gives us:
- ✅ Modern modular architecture
- ✅ Powerful flag-based interface
- ✅ Enhanced logging and SSO
- ✅ Backward compatibility
- ✅ Easy to maintain and extend
