# Evolution Protocol — Autonomous Architecture

> *How Hermes Agent, OpenCode, Telegram Gateway, Docker, and ParanoidX work together to create a self-evolving system.*

---

## System Diagram

```
                          ┌──────────────────────┐
                          │   Telegram (phone)   │
                          │   Approval Buttons   │
                          └──────────┬───────────┘
                                     │ long polling
                          ┌──────────▼───────────┐
                          │   Hermes Gateway     │
                          │   (Telegram Bridge)  │
                          └──────────┬───────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          ▼                          ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Hermes Agent   │    │   OpenCode CLI   │    │   Cron Jobs      │
│   (AI Core)      │    │   (coding agent) │    │   (background)   │
└──────┬───────────┘    └────────┬─────────┘    └────────┬─────────┘
       │                         │                       │
       └──────────┬──────────────┼───────────────────────┘
                  │              │
                  ▼              ▼
         ┌────────────────────────────┐
         │     Terminal Tools         │
         │  (build, test, git, curl)  │
         └────────────┬───────────────┘
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Go Build │ │ Docker   │ │ System   │
   │ simplex  │ │ 5 services│ │ commands │
   └──────────┘ └──────────┘ └──────────┘
```

---

## Components

### 1. Hermes Agent (AI Core)
- **Role:** Command interpreter, strategist, reporter
- **Provider:** OpenCode (DeepSeek V4 Flash Free) / OpenRouter
- **Config:** `~/.hermes/config.yaml`
- **Skills:** 30+ procedural memory files
- **Memory:** Cross-session memory + user profile

### 2. Hermes Gateway (Telegram Bridge)
- **Role:** Bridge between Telegram and AI core
- **Protocol:** Long polling (not webhook — no public URL needed)
- **Buttons:** Inline keyboard for approve/reject
- **Multi-platform:** Telegram, Discord, Signal, WhatsApp...

### 3. OpenCode CLI (Coding Agent)
- **Role:** Autonomous coding agent (alternative to Hermes for complex refactoring)
- **Provider:** DeepSeek V4 Flash Free
- **Integration:** Via opencode-tg-listener for Telegram reports

### 4. Docker (Containerization)
- **Services:** tor, v2ray/xray, smp-server, coturn, xftp-server
- **Network:** bridge + docker-compose
- **ParanoidX:** VMess + VLESS + Tor multi-layer routing

### 5. Cron Jobs (Automation)
- **Status Report:** Every hour → Telegram
- **Backups:** Every cycle
- **Health Check:** Every 5 minutes (systemd)

---

## Approval Process

```
User in Telegram:
  ┌─────────────────────────────────────┐
  │ 🤖 Execute: go build ./...          │
  │ ⚠️ Risk: MEDIUM                     │
  │                                     │
  │ [ ✅ Allow ] [ ❌ Deny ]             │
  └─────────────────────────────────────┘
         │                    │
         ▼                    ▼
  Hermes executes       Hermes cancels
  command               command
         │
         ▼
  Result → Telegram
```

**Risk Levels:**
- **LOW** — `flutter pub get`, `git status` — no confirmation
- **MEDIUM** — `go build`, `git commit` — request approval
- **HIGH** — `rm -rf`, `sudo` — mandatory request

---

## ParanoidX — Multi-Layer Routing

```
External World
     │
     ▼
┌─────────────┐     Port 10808     ┌─────────────┐
│  VMESS      │◄──────────────────│  V2Ray      │
│  (:10812)   │                   │  (Docker)   │
└──────┬──────┘                   └──────┬──────┘
       │                                 │
       ▼                                 ▼
┌─────────────┐     Port 10810     ┌─────────────┐
│  VLESS      │◄──────────────────│  XRay       │
│  (:10813)   │                   │  (native)   │
└──────┬──────┘                   └──────┬──────┘
       │                                 │
       ▼                                 ▼
┌─────────────┐                    ┌─────────────┐
│  TOR        │                    │  SimpleX    │
│  (:9050)    │                    │  (:17225)   │
└─────────────┘                    └─────────────┘
```

---

## Health Metrics

```json
{
  "healthy": true,
  "uptime_hours": 3.1,
  "build": "px-node-C41-C60",
  "bridge": true,
  "messages": 0,
  "dc_cloud": 0,
  "dc_seeding": 0
}
```

Check: `curl http://127.0.0.1:8080/api/health`

---

## Migration Path to New Hardware

1. **Beelink SER9** (26GB RAM, 500GB SSD, Ryzen 9) — future server
2. **OPNsense** — firewall with 3 VLANs: Mgmt, Onion, SMP
3. **Proxmox LXC** — virtualization instead of Docker
4. **500Mbps fiber** — instead of Tor-only

See `docs/TELEGRAM-GATEWAY.md` for remote control setup.