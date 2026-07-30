---
name: simplex-node-opencode
description: "OpenCode context and workflows for simplex-node (Saint Mary Liberty Island silver-backed digital economy)"
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [Coding-Agent, OpenCode, Simplex-Node, Silver-Economy, SimpleX, Tor]
    related_skills: [opencode, claude-code, codex, hermes-agent]
---

# Simplex-Node Project Context for OpenCode

## Project Overview
**simplex-node** — Go HTTP server for Saint Mary Liberty Island (silver-backed digital economy over SimpleX/Tor). Version A3.3 (Cycle 57). Monorepo at `/home/tomas/simplex-node`.

## User's OpenCode Setup
- Binary: `~/.opencode/bin/opencode` (v1.15.13)
- Config: `~/.config/opencode/opencode.jsonc` (minimal, schema only)
- Plugins: `@opencode-ai/plugin` (1.15.13), `@kilocode/plugin` (7.3.21)
- Auth: 6 providers configured (Nvidia, xAI, GitHub Copilot, OpenCode Zen, OpenAI, OpenRouter)
- Project plans: `~/.opencode/plans/` (CONTEXT.md, PLAN-A2.md, PLAN-A1.2.md, REPORT-2026-06-05.md)

## Project Structure (Key Paths)
```
/home/tomas/simplex-node/
├── cmd/simplex-node/main.go       # Main HTTP server (~3200 LOC)
├── cmd/banknote-press/main.go     # Banknote rendering service
├── internal/                      # 33 Go packages
│   ├── economy/                   # Core economy (ledger, auction, buyback, p2p, pack, registry, etc.)
│   ├── api/                       # REST handlers
│   ├── bot/                       # 4 Telegram bots (steward, torquemada, darkpushkin, nodeapi)
│   ├── steward/                   # AI Steward with 16 constitutional rules
│   ├── treasury/                  # Silver rounds, USDT monitoring
│   ├── press/                     # Banknote templates
│   ├── vault/                     # E2EE file storage
│   └── ... (ai, gateway, ton, webrtc, radio, channels, etc.)
├── docker/                        # 4 containers: SMP, XFTP, Tor (5 HS), Coturn
├── apps/                          # Flutter apps (royal_app, isle_app, shared)
├── scripts/                       # 18 shell/Python scripts
└── docs/                          # PRODUCTION-CYCLE.md, THEPLAN.md, etc.
```

## Flutter Apps Context
- Royal App (`apps/royal_app/`) — admin GUI (8 screens), Flutter Linux desktop
- Isle App (`apps/isle_app/`) — citizen GUI (9 tabs), Flutter Linux desktop
- Shared packages (`apps/shared/`) — models, api_client, widgets (path dependencies)
- **Flutter build on this hardware**: Always unset all proxy env vars before `flutter pub get` / `flutter build`. The `flutter_gen` import path doesn't work — use `royal_app/l10n/generated/app_localizations.dart` instead. See `linux-desktop-flutter-apps` skill's `references/flutter-build-fixes.md` for detailed error patterns and workarounds.

## Build/Test Commands
```bash
go build ./cmd/simplex-node/
go test ./... -short -count=1 -timeout 30s
go vet ./...
```

## Production Cycle (8-Step SOP)
Defined in `docs/PRODUCTION-CYCLE.md`:
1. BACKUP → 2. REWRITE THEPLAN → 3. REPORT TO ADMIN BOT → 4. CHOOSE STEPS → 5. BUILD → 6. TEST → 7. CREATE REPORT → 8. CALL ADMIN

## Key Economic Parameters
## Flutter Monorepo Architecture
See `references/flutter-monorepo-architecture.md` and `references/simplex-node-audit-2026-07-29.md` for detailed structure of:
- Shared packages: `models`, `api_client`, `widgets` (path dependencies)
- Unified `SimplexApiClient` with onion routing, typed endpoints, SSE, offline queue
- Isle app (9 tabs): Dashboard, Wallet, Market, Vault, Radio, Chat, ParanoidX, POS, Royal
- Royal app (8 admin screens): Dashboard, AI Office, Treasury, Comms, DC Cloud, Governance, System, Settings
- ParanoidX native engine: 4-layer proxy chain (V2Ray→VPN→Tor→SimpleX) via Kotlin MethodChannel

## Key Economic Parameters
``` NGPerTLR = 31,103,480,000 ng (1 troy oz silver)
SilverSpotUSDperOZ = 75.0 (oracle: metals.live)
SilverBackingRatio = 0.70 (70% physical silver)
UtilityPremiumPct = 0.30 (30% utility premium)
TreasuryCommissionBPS = 228 (2.28% on all operations)
```

## V2Ray Container Troubleshooting

### Common Failure: Missing config.json
**Symptom**: `simplex-node-v2ray` Docker container constantly restarting. Logs show:
```
Failed to load /etc/v2ray/config.json: no such file or directory
```
**Root cause**: Mounted host directory `/home/tomas/simplex-node/docker/v2ray/` is empty (owned by root with `drwxr-xr-x root root`). The `config.json` was deleted or never created.

**Fix**:
1. Restore config.json to `/home/tomas/simplex-node/docker/v2ray/config.json`
2. The container mount is: `Host /home/tomas/simplex-node/docker/v2ray/ → Container /etc/v2ray/`
3. Ownership must be `tomas:tomas` (or world-readable) for non-sudo writes
4. After config restored: `docker restart simplex-node-v2ray`
5. Verify: ParanoidX `/api/paranoidx/status` shows `layer: "v2ray", healthy: true`

**Config template** (basic SOCKS+HTTP proxy through freedom outbound):
```json
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {"port": 10808, "protocol": "socks", "settings": {"auth": "noauth", "udp": true, "ip": "0.0.0.0"}, "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}},
    {"port": 10809, "protocol": "http", "settings": {"timeout": 0}, "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}}
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"}
  ]
}
```

### ParanoidX Layer Status Endpoint
- `GET /api/paranoidx/status` — returns layers: v2ray (port 10808), vmess (port 10812), vless (port 10813), tor (port 9050), simplex (port 17225)
- Each layer has `healthy: bool`, `latency_ms`, `message`
- Docker `simplex-node-v2ray` container provides the v2ray SOCKS5+HTTP proxy layer

### Related Xray Processes (Native, Not Docker)
| Process | Config | Port |
|---------|--------|------|
| `xray run -c /home/tomas/bin/v2ray/config.json` | VLESS client | 10810 SOCKS |
| `xray run -c vless/server.json` | VLESS server | 10813 |  
| `xray run -c vmess/server.json` | VMESS legacy | 10812 |

## Flutter Shared Package: Dart Library-Level Privacy

**Problem**: Private methods (prefixed with `_`) in one `.dart` file are NOT accessible from other `.dart` files in the same package. Each file is its own library in Dart unless `part`/`part of` is used.

**In simplex-node**: `simplex_api_client.dart` defines `_get`, `_post`, `_getBytes` as private methods. `royal_client.dart` (separate file) calls `_client._get(...)` which fails with:
```
The method '_get' isn't defined for the type 'SimplexApiClient'.
```

**Fix**: Rename private methods to public by removing the underscore:
```dart
// Before (private — fails from other files)
Future<Map<String, dynamic>> _get(String path, ...) async { ... }

// After (public — works from all files)
Future<Map<String, dynamic>> get(String path, ...) async { ... }
```

Update all callers:
- `_client._get(` → `_client.get(`
- `_client._post(` → `_client.post(`
- `_client._getBytes(` → `_client.getBytes(`

**Why it compiled for `royal_app` but not `isle_app`**: The inline sub-classes (`WalletApi`, `MarketApi`, `TreasuryApi`, etc.) defined INSIDE `simplex_api_client.dart` CAN access private methods (same library). `royal_client.dart` is a separate file, so it cannot. `royal_app` may have cached a stale version.

## Adding Missing Model Types to Shared Package

When the shared `api_client` uses typed model classes but the `models` package doesn't define them yet, add them to the appropriate file under `apps/shared/models/lib/src/` and ensure they're exported from `models.dart`.

**Missing types to add** (from this session):
- `system_status.dart`: `SystemStatus`, `ServiceActionResult`, `BackupResult`, `CleanupResult`, `Config`, `MaintenanceMode`, `EmergencyStop`, `RateLimitStats`, `ContainerActionResult`
- `treasury.dart`: `ReserveState`, `BurnResult`, `ProofOfReserve`, `Rates`, `Tokenomics`, `Forecast`, `Constitution`, `Proposal`, `ProposalDraft`, `VoteResult`, `DelegationResult`, `SystemStatus`
- `vault.dart`: `UploadResult`, `DeleteResult`
- `token.dart`: `TokenBalancesResponse`, `TokenOperationResult`

**Pattern**: Each model class needs:
- `final` fields
- `const` constructor with defaults  
- `factory ClassName.fromJson(Map<String, dynamic> json)`

**Files that also need `import 'package:models/models.dart';`**: `token_client.dart`, `external_wallet_client.dart` (Dart doesn't re-export transitive imports).

## Telegram Approval Buttons Limitation

The user connects via **opencode-tg-bot**, not directly through Hermes Telegram Gateway. This means:
- Approval buttons ARE displayed in Telegram (rendered by opencode-tg-bot)
- BUT callback handling doesn't work — the opencode Telegram listener doesn't process inline keyboard callbacks
- **Fix**: Switch to direct Hermes Gateway for full callback button support, OR respond to approval prompts via text ("разрешить"/"да")

Set `approvals.mode: manual` so all potentially dangerous commands prompt for confirmation:
```bash
hermes config set approvals.mode manual
```

## Current Blockers
1. **King's artifacts needed**: Ed25519 signing key, PNG/SVG banknote templates, serial number scheme, pre-mint manifests
2. **6 critical bugs**: Data races (knownRoles, islandWS), connection leaks, nil derefs, stale configs
3. **TRON USDT live monitoring** (currently simulated)
4. **Banknote press integration** (PDF rendering + Ed25519 signing)

## Key Learnings (Cycle 57 / A3.3)

### Desktop Shortcut Debugging (Isle App + Royal App)
- **Root cause**: `.desktop` files pointed to `build/linux/x64/release/bundle/` but `install.sh` installs to `~/.local/bin/the-isle/isle_app` and `~/.local/bin/the-royal/royal_app`
- **Fix**: Update `.desktop` Exec paths to installed binaries, copy to `~/.local/share/applications/` and `~/Desktop/`, ensure icons in `~/.local/share/icons/hicolor/512x512/apps/`, run `update-desktop-database`
- **Validation**: `desktop-file-validate` passes for both

### V2Ray VMess → VLESS+Reality Migration (Complete)
- **Trigger**: Xray-core 26.3.27+ deprecates VMess (no forward secrecy, fingerprintable)
- **Ports**: VLESS client :10810, VLESS server :10813 (non-root), VMess legacy :10812 (to retire)
- **Key files**: `scripts/setup-vless.sh`, `internal/api/paranoidx_vless.go`, `scripts/logrotate-simplex-node`
- **Systemd**: User services at `~/.config/systemd/user/vless-server.service` and `v2raya.service`

### USB Backup Binary Recovery
- When Flutter build fails (bip32 version conflict + Tor proxy), USB backup at `/run/media/tomas/SIMPLEX-USB/backups/simplex-node-backup-*.tar.gz` contains working binaries
- Extract → locate binaries → copy to `~/.local/bin/` → verify → update shortcuts

### Flutter Dependency Conflict Resolution
- `bip32 ^3.0.0` not found on pub.dev → downgrade to `bip32 ^2.0.0` in `apps/shared/models/pubspec.yaml`
- Run `flutter pub get` in shared package FIRST, then dependent apps
- Unset proxy env vars: `env -u http_proxy -u https_proxy ... flutter pub get`

### Ad-Hoc Verification Script Pattern
Created `/tmp/hermes-verify-simplex-node.sh` checking:
- Go syntax (`gofmt -e`)
- Shell syntax (`bash -n`)
- Logrotate syntax (`logrotate --debug`)
- Desktop file validation
- Binary executability & icon presence
- Process cleanup (no root v2rayA, port 10808 freed)
- Expected Xray processes running (3)
- New files created
- Disk space improvement

## OpenCode Usage Patterns for This Project
- Plans stored in `~/.opencode/plans/` with CONTEXT.md + PLAN-*.md
- User runs opencode from project root: `/home/tomas/simplex-node/`
- Typical tasks: bug fixes (data races, leaks), feature work (SSE dashboard, auto-healer), refactoring main.go
- Test command: `go test ./internal/... -short -count=1 -timeout 120s`
- Always verify `go build ./cmd/simplex-node/` and `go vet ./...` after changes

## Communication & Reporting

- **All reports via Telegram**: Every build, audit, evolution step, and cycle report must be sent to Telegram with inline buttons (Build Status, Next Steps, Report Bug, Feedback). See `references/telegram-reporting.md` for exact API call and button layout.
- User prefers direct, technical communication — "bro" / informal tone accepted
- Values concise, actionable output over verbosity
- Wants real exploration/analysis, not summaries