---
name: codebase-audit
description: Systematic codebase audit workflow for finding bugs, security issues, and quality problems in local Go, Flutter/Dart, and script projects. Covers exploration, static analysis, bug classification, and structured reporting.
category: software-development
tags: [audit, code-quality, security, go, flutter, static-analysis, bug-hunting]
---

# Codebase Audit Skill

Systematic approach to auditing a local codebase for bugs, security vulnerabilities, and quality issues. Designed for Go + Flutter/Dart + script polyglot projects.

## Trigger Conditions
- User asks to "audit", "explore", "review", or "find bugs in" a local codebase
- Need to produce a structured bug report with severity classifications
- Comparing against a prior audit report (regression detection)

## Workflow

### Phase 1: Reconnaissance (5-10 min)
1. **Map the project structure**
   ```bash
   ls -la /path/to/project
   find /path/to/project -name "*.go" -o -name "*.dart" -o -name "*.sh" | head -50
   ```
2. **Identify entry points** — `main.go`, `main.dart`, `go.mod`, `pubspec.yaml`
3. **Check build status** — `go build ./...`, `flutter analyze`
4. **Run static analysis** — `go vet ./...`, `golangci-lint run` (if available)

### Phase 2: Deep Dive (15-30 min)
1. **Read entry points first** — understand architecture from `main.go` / `main.dart`
2. **Trace critical paths** — auth, payments, network, file I/O, concurrency
3. **Search for known bug patterns**:
   ```bash
   # Missing methods / undefined references
   grep -r "undefined" /path/to/project 2>/dev/null || go build ./... 2>&1
   
   # Goroutine leaks
   grep -r "go func()" /path/to/project --include="*.go" | grep -v "_test.go"
   
   # File descriptor leaks
   grep -r "os\.Create\|os\.OpenFile" /path/to/project --include="*.go" | grep -v "defer.*Close"
   
   # Hardcoded secrets/IPs
   grep -rE "(password|secret|api[_-]?key|192\.168\.|10\.0\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.)" /path/to/project --include="*.go" --include="*.dart" | grep -v test
   
   # TODO/FIXME/BUG markers
   grep -r "TODO\|FIXME\|BUG\|XXX" /path/to/project --include="*.go" --include="*.dart"
   ```

### Phase 3: Classification & Verification
For each finding, assign severity:
- **CRITICAL** — Build fails, data loss, RCE, auth bypass
- **HIGH** — Goroutine/FD leaks, race conditions, DoS vectors
- **MEDIUM** — Logic bugs, unused code, missing context propagation, hardcoded config
- **LOW** — Dead code, unused imports, lint warnings, cosmetic

Verify each finding:
- Can it be reproduced? (build error, test failure, race detector)
- Is it a false positive? (generated code, test files, intentional)

### Phase 4: Report Generation
Produce structured markdown report with:
- Executive summary (counts by severity, build status)
- Per-bug: severity, file:line, description, reproduction steps, impact, fix
- Comparison table vs prior audit (if available)
- Prioritized action plan (immediate/short/medium/ongoing)
- File index for quick navigation

## Tool Preferences
- **Exploration**: `terminal` (ls, find, grep), `read_file`, `search_files`
- **Static analysis**: `go build`, `go vet`, `go test -race`, `flutter analyze`
- **No browser/web tools** — this is local filesystem only
- **No interactive editors** — read-only analysis

## Output Format
Markdown report saved to `<project>/AUDIT-REPORT-<DATE>.md` with:
- Severity-emoji headers (🔴 🟠 🟡 🟢 🔵)
- Reproducible commands for each finding
- Diff against prior audit (if `AUDIT-REPORT.md` exists)

## Pitfalls & Gotchas
- ❌ Don't assume `go build` passes — always run it first
- ❌ Don't skip `go test -race` — catches data races static analysis misses
- ❌ Don't trust "FIXED" claims in old reports — re-verify on current code
- ❌ Don't ignore generated/vendor files — filter with `--include/--exclude`
- ❌ Don't forget Flutter/Dart side — `flutter analyze` finds different issues
- ✅ Always check `go.mod`/`go.sum` for dependency risks
- ✅ Cross-reference findings between Go and Dart (shared API contracts)
- ✅ Use `session_search` to recall prior audit context if available
- ✅ **Handle partial builds**: if some packages fail to compile, test/vet the working ones first (`go test ./pkg/...`), then fix blockers
- ✅ **Use ad-hoc verification scripts** for targeted fix validation (see `scripts/verify-fix.sh` template)
- ✅ **Comparison mode**: when auditing against prior reports, include a diff table in output (fixed/regressed/new)
- ✅ **Race detector timeouts**: some packages (bcrypt cost=10, heavy crypto) timeout under `-race`; use `go test -race ./pkg/... -timeout 300s` per-package or lower bcrypt cost in tests
- ✅ **Build caching**: first `go build ./cmd/...` after changes may timeout (dependency resolution); retry usually succeeds
- ✅ **Flutter/Go contract drift**: check API endpoint paths, JSON field names, and WebSocket messages match between sides
- ✅ **Monorepo disk cleanup**: after audits, clean build artifacts to reclaim space:
  - Flutter: `.dart_tool/`, `build/`, `*.iml`, `pubspec.lock` (rebuildable with `flutter pub get`)
  - Go: `go clean -modcache`, `go clean -cache` (rebuildable with `go mod download`)
  - IDE: `.idea/`, `*.iml` files
  - Archives: `*.zip`, `*.tar.gz` build outputs
  - Use `du -sh` to identify largest dirs, `df -h` to track free space
- ✅ **Session persistence**: save audit reports to project root (`AUDIT-REPORT-<DATE>.md`) and cross-reference with prior audits using session_search

### Desktop Shortcut Debugging Methodology
When desktop shortcuts fail to launch apps:
1. **Check the `.desktop` file `Exec` path** — compare against actual installed binary location
2. **Read the project's `install.sh` script** — it reveals the true install destination (e.g., `~/.local/bin/the-isle/isle_app` vs build dir `build/linux/x64/release/bundle/`)
3. **Verify binary exists and is executable** — `ls -la /actual/install/path/binary`
4. **Validate `.desktop` file** — `desktop-file-validate /path/to/app.desktop`
5. **Update `.desktop` to point to installed binary** — copy to `~/.local/share/applications/` and `~/Desktop/`
6. **Ensure icons exist** — copy from app's `icons/` to `~/.local/share/icons/hicolor/512x512/apps/`
7. **Refresh desktop database** — `update-desktop-database ~/.local/share/applications/`

### V2Ray VMess → VLESS+Reality Migration Pattern
When Xray-core deprecates VMess (no forward secrecy, fingerprintable):
1. **Generate Reality keypair** — `xray x25519` outputs PrivateKey + PublicKey + Hash32
2. **Create server config** — VLESS inbound on non-root port (e.g., 10813), Reality settings with dest=www.microsoft.com:443, sni=www.microsoft.com
3. **Create client config** — VLESS outbound to server port, Reality with pbk=server_public_key, fp=chrome, sni=www.microsoft.com, sid=short_id
4. **Patch main xray config with jq** — merge inbound/outbound into existing config
5. **Create systemd user service** — `~/.config/systemd/user/vless-server.service`, `ExecStart=xray run -c /path/to/server.json`
6. **Enable & start** — `systemctl --user daemon-reload && systemctl --user enable --now vless-server.service`
7. **Verify** — `ss -tlnp | grep 10813` and `systemctl --user status vless-server.service`
8. **Add API handlers** — REST endpoints for status/init/rotate/config
9. **Log rotation** — create `/etc/logrotate.d/simplex-node` for Xray logs

### USB Backup Binary Recovery
When Flutter/Go build fails due to dependency issues but USB backup has working binaries:
1. **Extract backup** — `tar -xzf /media/usb/backups/project-backup-<date>.tar.gz -C /tmp/restore/`
2. **Locate binaries** — `find /tmp/restore -name "binary_name" -executable`
3. **Copy to install dir** — `cp /tmp/restore/.../binary ~/.local/bin/app-name/binary`
4. **Verify** — `file ~/.local/bin/app-name/binary` and test launch
5. **Update desktop shortcuts** — ensure `.desktop` points to recovered binary

### Flutter Dependency Conflict Resolution
When `flutter pub get` fails with version conflicts in shared packages:
1. **Check `pubspec.lock`** in shared package for pinned versions
2. **Identify conflicting dependency** — error message shows package and required version
3. **Downgrade in shared package `pubspec.yaml`** — e.g., `bip32: ^3.0.0` → `bip32: ^2.0.0`
4. **Run `flutter pub get` in shared package first**, then dependent apps
5. **Unset proxy env vars** if using Tor — `env -u http_proxy -u https_proxy ... flutter pub get`

### Ad-Hoc Verification Script Template
For multi-faceted validation after fixes, create a script checking:
```bash
#!/bin/bash
# verify-fixes.sh
checks=(
  "gofmt -e <new_go_file.go>      # Go syntax"
  "bash -n <new_script.sh>        # Shell syntax"
  "logrotate --debug <config>     # Logrotate syntax"
  "desktop-file-validate <.desktop> # Desktop entries"
  "[[ -x <binary_path> ]]         # Executable exists"
  "[[ -f <icon_path> ]]           # Icons present"
  "! ps aux | grep <bad_process>  # Cleanup verified"
  "! ss -tlnp | grep <bad_port>   # Port freed"
  "ps aux | grep <good_process>   # Expected running"
  "[[ -f <new_file> ]]            # New files created"
)
# Run all, report pass/fail
```

### Post-Session Skill Update Protocol
After completing an audit session, update this skill with:
1. **New bug patterns discovered** — add to Phase 2 search patterns
2. **New fix patterns** — add to methodology sections
3. **New reference files** — create in `references/` for session-specific details
4. **Verification script improvements** — update template with new checks

This ensures the skill evolves with real project experience rather than staying theoretical.

## References
- `references/audit-checklist.md` — comprehensive pattern checklist
- `references/severity-guide.md` — severity calibration examples
- `references/royal-app-audit-2026-07-25.md` — Isle Royal admin app audit findings
- `references/isle-app-audit-2026-07-26.md` — Isle citizen app audit findings (this session)
- `references/bip39-onboarding-analysis.md` — BIP39 onboarding security analysis & recommendations
- `references/v2ray-vless-migration.md` — V2Ray VMess → VLESS+Reality migration steps & configs
- `references/desktop-shortcut-debugging.md` — Desktop shortcut debugging methodology & session example
- `references/simplex-node-audit-2026-07-29.md` — Complete session findings, fixes, and lessons
- `templates/audit-report.md` — report template with all sections
- `templates/bip39-onboarding.dart` — standard BIP39 onboarding implementation template
- `scripts/verify-fix.sh` — ad-hoc verification script template