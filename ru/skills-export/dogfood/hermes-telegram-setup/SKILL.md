---
name: hermes-telegram-setup
description: Full Hermes Telegram setup - auth, persist, cron reports.
---

# Hermes Telegram Integration — Full Setup

Complete flow from zero to working bot with persistent automation (survives reboot, delivers reports on schedule).

## 1. Locate the Running Gateway
The gateway may bind to a dynamic port. Don't assume 8080 or 44787:
```bash
ps aux | grep gateway
lsof -i -p <PID> | grep LISTEN
```
API health: `curl http://localhost:<PORT>/api/health`

## 2. Fix "Unauthorized User" Error

**Root cause**: `TELEGRAM_ALLOWED_USERS` not set in `~/.hermes/.env`.

**Diagnose**: Check `~/.hermes/logs/gateway.log` for:
```
WARNING gateway.run: Unauthorized user: <CHAT_ID> on telegram
WARNING gateway.run: No env user allowlists configured.
```

**Fix:**
1. Edit `~/.hermes/.env` to uncomment and set:
   ```
   TELEGRAM_ALLOWED_USERS=143293811
   TELEGRAM_HOME_CHANNEL=143293811
   ```
2. Delete any conflicting webhook (gateway uses polling mode):
   ```bash
   curl -s -X POST "https://api.telegram.org/bot<TOKEN>/deleteWebhook" \
     -H "Content-Type: application/json" \
     -d '{"drop_pending_updates": true}'
   ```
3. Restart gateway:
   ```bash
   systemctl --user restart hermes-gateway.service
   ```
4. Verify in logs: `✓ telegram connected`, `Sending response to <CHAT_ID>`

## 3. Make It Survive Reboot

The gateway auto-starts via systemd user service:
```bash
systemctl --user status hermes-gateway.service
systemctl --user is-enabled hermes-gateway.service   # should be 'enabled'
loginctl enable-linger tomas                         # must be 'yes'
```

Key files that persist:
- `~/.hermes/.env` — Telegram token, allowed users, home channel
- `~/.hermes/config.yaml` — Gateway config
- `~/.hermes/gateway_state.json` — Runtime state

## 4. Schedule Recurring Status Reports to Telegram

**No-agent pattern**: Script stdout delivers verbatim as Telegram message.

1. Create a status script at `~/.hermes/scripts/status-report.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
UPTIME=$(uptime -p | sed 's/up //')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
MEM=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
GATEWAY_PID=$(pgrep -f "hermes_cli.main gateway run")
GATEWAY_LINE=$(ps -p "$GATEWAY_PID" -o %cpu=,rss= 2>/dev/null)
SESSION_CNT=$(find ~/.hermes/sessions -name "*.json" 2>/dev/null | wc -l)
cat <<REPORT
🏰 **Status Report** $(date '+%Y-%m-%d %H:%M')
...
REPORT
```

2. Schedule via cronjob tool:
```bash
cronjob(action='create',
  name='island-status-report',
  schedule='every 15 min',
  script='status-report.sh',    # relative to ~/.hermes/scripts/
  no_agent=True,
  deliver='telegram:CHAT_ID')
```

3. Verify: `cronjob(action='list')` shows `last_status: ok`

## 5. Test the Pipeline

```bash
# Run script directly to see its output
bash ~/.hermes/scripts/status-report.sh

# Check gateway log for deliveries
tail -10 ~/.hermes/logs/gateway.log
# Look for: Sending response (...) to <CHAT_ID>

# Forced manual run of cron job
cronjob(action='run', job_id='...')
```

## Known Issues
- **Webhook conflict**: Calling `setWebhook` breaks polling mode. Only use `deleteWebhook`.
- **Polling auto-reconnect**: If previous polling session is still open, gateway waits 20s and retries (up to 5 times).
- **Dynamic ports**: Gateway API may be on any port; find it with `lsof` on the PID.
- **Tor proxy**: Gateway auto-discovers `socks5://127.0.0.1:9050` if available. May cause slower initial connection.