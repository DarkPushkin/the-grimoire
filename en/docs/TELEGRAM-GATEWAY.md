# Telegram Gateway — Approval Interface with Buttons

**Setting up Hermes Telegram Gateway for remote evolution control from your phone.**

---

## Why?

Sitting at a laptop 24/7 — broken back. Telegram interface with buttons allows:
- Approve/reject actions with one tap
- Receive reports and status in real time
- Voice commands (Telegram voice → STT)
- Control evolution from phone anywhere in the world

---

## Architecture

```
┌─────────────────┐     Telegram API     ┌──────────────────┐
│   Telegram App  │◄──────────────────►  │  Hermes Gateway  │
│   (phone)       │    long polling      │  (server)        │
└─────────────────┘                      └────────┬─────────┘
                                                   │
                                                   ▼
                                          ┌──────────────────┐
                                          │  Hermes Agent    │
                                          │  (AI core)       │
                                          └────────┬─────────┘
                                                   │
                                                   ▼
                                          ┌──────────────────┐
                                          │  Terminal Tools  │
                                          │  (commands, code)│
                                          └──────────────────┘
```

---

## Installation on New Device

### Step 1: Install Hermes Agent

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
```

### Step 2: Create Telegram Bot

1. Open Telegram → find @BotFather
2. Send `/newbot`
3. Name it (e.g., `IsleStewardBot`)
4. Get token like `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`

### Step 3: Configure Hermes Gateway

```bash
# Setup provider and model
hermes setup

# Configure Telegram
hermes config set TELEGRAM_BOT_TOKEN "your_token_here"
# OR via .env: TELEGRAM_BOT_TOKEN=your_token

# Allow only yourself (by user_id)
hermes config set TELEGRAM_ALLOWED_USERS "143293811"
```

### Step 4: Enable Approval Buttons

```bash
hermes config set approvals.mode manual
```

### Step 5: Start Gateway

```bash
# Start gateway server
hermes gateway run

# Or install as systemd service
hermes gateway install
```

### Step 6: Connect

1. Find your bot in Telegram
2. Press /start
3. Done! All approval requests arrive with ✅ buttons

---

## Approval Button Structure

When Hermes wants to execute an action requiring approval:

```
⚠️ Execution Request:
  Command: go build ./cmd/simplex-node/
  Risk: MEDIUM (code compilation)
  Session: CLI #3

[ ✅ Allow ] [ ❌ Deny ] [ ⏰ 5 min ]
```

- **Allow** — execute now
- **Deny** — reject
- **5 min** — defer 5 minutes (reminder)

Timeout config:
```bash
hermes config set approvals.timeout 120  # seconds
```

---

## Config Transfer to Another Laptop

### Option A: Via This Repo

```bash
# On new laptop
git clone https://github.com/PerfectFriend/evolution-protocol.git ~/evolution-protocol
cp ~/evolution-protocol/configs/hermes-config.yaml ~/.hermes/config.yaml
# Edit secrets in .env
hermes gateway run
```

### Option B: Automatic Bootstrap

```bash
bash ~/evolution-protocol/scripts/bootstrap.sh
```

### Option C: Manual Setup

```bash
# Minimal config
hermes config set approvals.mode manual
hermes config set terminal.backend local
hermes config set display.skin default
# Telegram token in .env
echo 'TELEGRAM_BOT_TOKEN=your_token' >> ~/.hermes/.env
hermes gateway run
```

---

## Critical config.yaml Settings

```yaml
approvals:
  mode: manual           # ALWAYS request approval
  timeout: 120           # Wait timeout for response

telegram:
  allowed_users:
    - "143293811"        # Only you
  home_channel: "143293811"
  parse_mode: markdown   # Nice formatting
```

---

## Telegram Voice Commands

Telegram supports voice messages. Hermes automatically:
1. Transcribes voice → text (via Whisper/local STT)
2. Executes command
3. Responds with text or voice

No extra config needed — works out of the box.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Buttons don't work | Hermes must run via `hermes gateway run`, not `opencode-tg-bot` |
| No bot response | Check `hermes gateway status`, logs: `journalctl -u hermes-gateway` |
| Tor blocks Telegram API | `unset HTTP_PROXY HTTPS_PROXY` before starting gateway |
| "Bot token is invalid" | Check TELEGRAM_BOT_TOKEN in .env, recreate at @BotFather |

---

*Your back will thank you.*