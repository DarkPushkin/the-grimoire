---
name: telegram-gateway-auth
description: Fix Hermes Telegram auth - allowlist + webhook conflict fix.
---

# Telegram Gateway Auth & Fix Workflow

## Quick Fix: Unauthorized User
```bash
# 1. Set TELEGRAM_ALLOWED_USERS in .env
# Edit ~/.hermes/.env:
TELEGRAM_ALLOWED_USERS=143293811

# 2. Remove conflicting webhook (prevents polling)
curl -s -X POST "https://api.telegram.org/bot<TOKEN>/deleteWebhook" \
  -H "Content-Type: application/json" \
  -d '{"drop_pending_updates": true}'

# 3. Restart gateway
pkill -f "hermes_cli.main gateway run"
```

## Full Authorization Flow

1. **Identify the gateway process**:
   ```bash
   ps aux | grep gateway
   lsof -i -p <PID> | grep LISTEN
   ```

2. **Delete any conflicting webhook** (webhook and polling can't coexist):
   ```bash
   curl -s -X POST "https://api.telegram.org/bot<TOKEN>/deleteWebhook" \
     -H "Content-Type: application/json" \
     -d '{"drop_pending_updates": true}'
   ```

3. **Configure allowlist** in `~/.hermes/.env`:
   ```
   TELEGRAM_ALLOWED_USERS=143293811
   ```
   (Alternative: `GATEWAY_ALLOW_ALL_USERS=true` for open access)

4. **Restart the gateway**:
   ```bash
   /home/tomas/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run &
   ```

5. **Verify connection** in `~/.hermes/logs/gateway.log`:
   - Look for `✓ telegram connected`
   - Look for `set_my_commands OK`
   - Look for `Sending response to 143293811`

6. **Test bot commands**:
   ```bash
   curl -s -X POST "https://api.telegram.org/bot<TOKEN>/getUpdates?limit=1"
   ```

## Known Issues
- **Polling conflict**: If previous session is still open, gateway waits 20s and retries (up to 5 times). Delete webhook first.
- **Webhook conflict**: Don't call `setWebhook` — it breaks polling mode. Only use `deleteWebhook`.
- **Tor/proxy**: Gateway auto-discovers `socks5://127.0.0.1:9050` proxy if available.