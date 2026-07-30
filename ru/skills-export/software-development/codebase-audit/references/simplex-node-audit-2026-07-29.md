# Simplex-Node Audit Session 2026-07-29 — Key Findings & Fixes

## Project Overview
- **Path**: `/home/tomas/simplex-node`
- **Architecture**: 4 Go services + 3 Flutter apps + 3 shared packages + 9 internal packages
- **Hardware**: Dell Latitude 3150 (2014), no battery, broken backspace key
- **Method**: Evolution Loop - 20-cycle autonomous evolution via opencode + DeepSeek V4 free

## Issues Found & Fixed

### 1. Disk Space Critical (93% → 86%)
**Freed**: ~3.8 GB
- Downloads installers: 439 MB (Claude Desktop, Chrome, Tor Browser, game zips)
- Simplex-node build artifacts: 429 MB (windows zip, tar.gz, build dirs)
- Go module cache: 716 MB (`go clean -modcache`)
- Go build cache: 1.1 GB (`go clean -cache`)
- System caches: 2.4 GB (Chrome, tracker3, opencode, electron, etc.)

### 2. V2Ray/ParanoidX Issues
**Problem**: 
- v2rayA running as root (PID 3759) on port 10808
- VMess deprecated warnings in Xray logs ("no Forward Secrecy")
- Orphaned docker-proxy on port 10808
- 3 Xray processes consuming resources

**Root Cause**: Multiple independent V2Ray configs:
1. `~/bin/v2ray/config.json` — v2rayA GUI (root process)
2. `~/.local/share/simplex-node/vmess/server.json` — VMess server :10812
3. `~/.local/share/simplex-node/v2ray/config.json` — V2Ray→Tor proxy :10808
4. `KiloParanoidX/v2ray.json.example` — standalone docker-compose
5. `internal/paranoidx/v2ray.go` — programmatic manager

**Fixes Applied**:
- Killed root v2rayA process, created user systemd service
- Freed port 10808 (stopped docker container)
- Created VLESS+XTLS-Reality migration:
  - `scripts/setup-vless.sh` — generates Reality keypair, server/client configs, systemd service
  - `internal/api/paranoidx_vless.go` — 4 API handlers (status/init/rotate/config)
  - Registered in `cmd/simplex-node/main.go`
  - VLESS server running on :10813 (non-root port)
  - Client on :10810 → VLESS server :10813 → www.microsoft.com:443 (Reality)
- Log rotation: `scripts/logrotate-simplex-node` (daily, 14-day retention)

### 3. Desktop Shortcuts - Major Confusion
**Problem**: Two shortcuts both launching wrong/old apps
- "The Island" → pointed to isle_app (but name suggested citizen app)
- "Isle Royal" → pointed to old royal_app binary in ~/.local/bin/the-royal/

**Root Cause**: 
- USB backup had working `flutter/.local/bin/the-isle/isle_app` which IS the Royal Isle admin app (package ID: `org.stmaria.the_island`)
- Current `apps/royal_app` has build errors (dependency conflicts)
- Desktop files pointed to non-existent build directories

**Fix Applied**:
1. Deleted `/home/tomas/.local/bin/the-royal/` and all its `.desktop` files
2. Copied working Royal Isle binary from USB backup to `~/.local/bin/the-isle/isle_app`
3. Created single `royal-island.desktop` pointing to the working binary
4. Removed confusing "The Island" shortcut
5. Result: One "Royal Island" shortcut launching correct admin app

### 4. Life Elements Game Extraction
- Extracted `/home/tomas/simplex-node/apps/life_elements_game` → `/home/tomas/LifeElementGame`
- `flutter pub get` ✅, `flutter build linux` ✅ (with deprecation warnings)
- Linux binary at `build/linux/x64/debug/runner`

### 5. New VLESS+Reality API Handlers
Added to `internal/api/paranoidx_vless.go`:
- `InitVLESS(dataDir)` — auto-initializes on simplex-node startup
- `VLESSStatusHandler()` — GET /api/paranoidx/vless/status
- `VLESSInitHandler()` — POST /api/paranoidx/vless/init  
- `VLESSRotateHandler()` — POST /api/paranoidx/vless/rotate
- `VLESSConfigHandler()` — GET /api/paranoidx/vless/config
- Registered in `main.go` lines 1736-1742

### 6. Go Build Blocked by External Dependency
- `modernc.org/sqlite` 403 from proxy.golang.org
- Version pinned at v1.52.0 in go.sum
- Code syntax valid (`gofmt -e` passes)
- **Not a code issue** — upstream/network problem

## Key Scripts Created
| Script | Purpose |
|--------|---------|
| `scripts/setup-vless.sh` | VLESS+Reality init (keypair, configs, systemd) |
| `scripts/logrotate-simplex-node` | Daily log rotation for Xray logs |
| `internal/api/paranoidx_vless.go` | VLESS REST API handlers |

## Verification Script
`/tmp/hermes-verify-simplex-node.sh` — 12 checks covering:
- Go/shell/logrotate/desktop syntax
- Binary/icon existence
- Process cleanup (no root v2rayA)
- Port cleanup (10808 freed)
- Xray process count
- New file creation
- Disk space

## Remaining Work
1. Retire legacy VMess server (:10812) once VLESS verified stable
2. Install logrotate config: `sudo cp scripts/logrotate-simplex-node /etc/logrotate.d/simplex-node`
3. Fix `modernc.org/sqlite` dependency (wait for proxy fix or vendor)
4. Build Flutter apps once deps resolve (shared/models bip32 conflict)

## Lessons for Skill Updates
- **Desktop shortcut debugging**: Always read `install.sh` first — it reveals true install path
- **USB backup recovery**: Working binaries often in backup when build fails
- **V2Ray→VLESS migration**: Reality keypair via `xray x25519`, non-root port, systemd user service
- **Ad-hoc verification script**: Essential for multi-faceted fix validation
- **Post-session skill update**: Capture new patterns immediately while fresh