# PROJECT-NAME — Agent Guide for Autonomous Evolution

## Quick Start
```bash
go build ./cmd/project/
go test ./... -short -count=1 -timeout 30s
go vet ./...
```

## Structure
| Path | Purpose |
|------|---------|
| `cmd/` | Entrypoints |
| `internal/*/` | Go packages |
| `apps/` | Flutter apps |
| `docker/` | Docker configs |
| `scripts/` | Automation |
| `docs/` | Plans, SOPs |

## Critical Commands
- **Build**: `go build ./cmd/project/`
- **Tests**: `go test ./... -short -count=1 -timeout 30s`
- **Race check**: `go test -race ./internal/...`
- **Lint**: `go vet ./...`

## Reports
- **Script**: `scripts/send-to-inquisitor.sh "message"`
- **Token**: `~/.config/opencode-tg-bot.token`
- **Chat ID**: `143293811`
- Messages are plain text, max 4000 chars

## Evolution Protocol
1. **Backup** — source + data snapshot
2. **Plan** — update THEPLAN.md
3. **Report Plan** — send to Inquisitor Bot
4. **Choose** — 1-3 steps (bugs > security > features)
5. **Build** — each step: build → vet → commit
6. **Test** — unit → integration → race → lint
7. **Report** — what done → results → issues
8. **Call Admin** — approve/adjust/reject → cycle start

## Telegram Control
- **Gateway**: Hermes Telegram Gateway
- **Approvals**: `approvals.mode: manual` — buttons in Telegram
- **Bot**: @YourBotName
- **Cron**: `cronjob` tool — hourly status reports

## Key Parameters
```
NGPerTLR = 31,103,480,000
SilverSpotUSDperOZ = 75.0
SilverBackingRatio = 0.70
UtilityPremiumPct = 0.30
Issuance: Investor 70% | Treasury 4.2% | DividendPool 12.9% | ...
```

## Prohibited
- No `os.Exit(1)` on listen failure
- No direct binary start (use launch script or systemd)
- No `sudo` without explicit permission