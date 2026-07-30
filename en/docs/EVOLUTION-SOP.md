# Evolution SOP — Standard Operating Procedure

**Version:** 2.0
**Project:** Saint Mary Liberty Island / simplex-node
**Cycle:** Evolutionary — infinite

---

## Preamble

Each production cycle follows exactly 8 steps. None are skipped.
The cycle begins with a backup and ends with the Administrator's approval.

---

## Step 1: BACKUP

Save state before any changes.

```bash
# Source snapshot
tar -czf /tmp/cycle-$(date +%Y%m%d-%H%M)-source.tar.gz /home/tomas/simplex-node/

# Data snapshot (registries, ledger, vault, configs)
cp ~/.local/share/simplex-node/ /home/tomas/A1-backups/cycle-N/data/

# MANIFEST
cat > /home/tomas/A1-backups/cycle-N/MANIFEST.txt << EOF
Cycle: N
Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Version: A2.0
Build: px-node-CXX-CYY
Backup by: Hermes Agent
EOF
```

**Verification:** `diff -r ~/.local/share/simplex-node/ /home/tomas/A1-backups/cycle-N/data/`

---

## Step 2: PLAN

Rewrite THEPLAN.md considering:
- Current project state
- New requests from administrator
- Priorities: bugs > security > features
- Previous test results

```bash
cat docs/PRODUCTION-CYCLE.md docs/EVOLUTION-PLAN.md > /tmp/cycle-context.md
```

---

## Step 3: REPORT PLAN

Send plan to Inquisitor Bot:

```bash
bash scripts/send-to-inquisitor.sh "Cycle N Plan: ..."
```

**Channel:** Telegram @opencode-tg-bot
**Token:** `~/.config/opencode-tg-bot.token`
**Chat ID:** `143293811`

---

## Step 4: CHOOSE STEPS

Select 1-3 steps for current cycle:
- Priority: bug fixes → security → new features
- Maximum 3 steps per cycle (focus)
- Report chosen steps to administrator

---

## Step 5: BUILD

After each change:
```bash
go build ./cmd/simplex-node/    # Must pass
go vet ./...                    # Must pass
```

Commit after each completed step:
```bash
git add -A && git commit -m "Cycle N: Step description"
```

---

## Step 6: TEST + DEBUG

```bash
# Short tests
go test ./... -short -count=1 -timeout 30s

# Specific package test
go test ./internal/economy/... -count=1

# Race detector (except internal/lock — bcrypt cost=10)
go test -race ./internal/... -count=1 -timeout 60s 2>&1 | grep -v "internal/lock"

# Integration tests (if applicable)
bash scripts/test-royal.sh

# Linting
go vet ./...
```

If test fails: debug → fix → re-test.

---

## Step 7: CREATE REPORT

Report format:
1. What was done (completed steps)
2. What changed (modified files, new files)
3. Test results (pass/fail, coverage)
4. Issues found
5. What's next (recommendations for next cycle)
6. Send to Inquisitor Bot

```bash
bash scripts/send-to-inquisitor.sh "Cycle N Report: ..."
```

---

## Step 8: CALL ADMIN

1. Present report
2. Ask: approve, adjust, or reject
3. If approve → start next cycle (step 1)
4. If adjust → update plan, restart cycle
5. If reject → stop, document reason

---

## Telegram Gateway — Approval Buttons

At each step requiring approval (steps 3, 4, 7, 8), request arrives in Telegram with buttons:

```
🤖 Hermes Agent requests permission:
  Execute: go build ./cmd/simplex-node/
  Risk: MEDIUM

[ ✅ Allow ] [ ❌ Deny ] [ 🔄 Modify ]
```

Configuration:
```bash
hermes config set approvals.mode manual
```

---

## Glossary

| Term | Description |
|------|-------------|
| Cycle | One iteration of the 8-step process |
| Epoch | 20 cycles (full evolutionary epoch) |
| THEPLAN.md | Living strategy document |
| Inquisitor Bot | Telegram bot for reports (@opencode-tg-bot) |
| AGENTS.md | Context file for opencode/Hermes |
| ParanoidX | Multi-layer routing system (VMess + VLESS + Tor) |

---

*Ad gloriam Dei et libertatem Insulae Sanctae Mariae.*