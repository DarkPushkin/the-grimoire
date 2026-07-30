# V2Ray → VLESS+Reality Migration Reference

## Context
Discovered during simplex-node audit (July 2026). The ParanoidX package implements a 4-layer proxy chain: **V2Ray → Tor → SimpleX → VPN**. The legacy VMess protocol is deprecated in Xray-core and emits constant warnings:

```
The feature VMess (with no Forward Secrecy, etc.) is deprecated and is removed from Xray-core since 26.3.27
```

## Migration Steps Completed

### 1. New Setup Script (`scripts/setup-vless.sh`)
- Generates X25519 Reality keypair
- Creates server.json (VLESS+Reality on port 10813)
- Creates client_patch.json (VLESS client config for port 10810)
- Patches main xray config via jq
- Creates systemd user service: `vless-server.service`

### 2. New API Handlers (`internal/api/paranoidx_vless.go`)
- `InitVLESS(dataDir)` - auto-initialization on node startup
- `VLESSStatusHandler()` - GET /api/paranoidx/vless/status
- `VLESSInitHandler()` - POST /api/paranoidx/vless/init
- `VLESSRotateHandler()` - POST /api/paranoidx/vless/rotate
- `VLESSConfigHandler()` - GET /api/paranoidx/vless/config

### 3. Systemd User Service
```ini
# /home/tomas/.config/systemd/user/vless-server.service
[Unit]
Description=ParanoidX VLESS+Reality Server (xray-core)
After=network.target

[Service]
Type=simple
ExecStart=/home/tomas/bin/v2ray/xray run -c /home/tomas/.local/share/simplex-node/vless/server.json
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=default.target
```

### 4. Port Allocation
| Port | Protocol | Purpose |
|------|----------|---------|
| 10810 | VLESS+Reality | Client inbound (SOCKS5) |
| 10812 | VMess | Legacy server (to retire) |
| 10813 | VLESS+Reality | Server inbound (replaces VMess :443) |

### 5. Log Rotation (`scripts/logrotate-simplex-node`)
```conf
/home/tomas/.local/share/simplex-node/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 tomas tomas
    sharedscripts
    postrotate
        systemctl --user reload xray-vmess > /dev/null 2>&1 || true
        systemctl --user reload xray-vless > /dev/null 2>&1 || true
        pkill -HUP -x xray 2>/dev/null || true
    endscript
}
```

## Verification Commands
```bash
# Check VLESS server running
ss -tlnp | grep 10813
systemctl --user status vless-server.service

# Test client connectivity
curl --socks5 127.0.0.1:10810 https://www.microsoft.com -v

# Check logs
cat /home/tomas/.local/share/simplex-node/logs/vless-server.log
journalctl --user -u vless-server -f
```

## Client URI Format
```
vless://<UUID>@127.0.0.1:10813?type=tcp&security=reality&pbk=<PUBLIC_KEY>&fp=chrome&sni=www.microsoft.com&sid=<SHORT_ID>&flow=xtls-rprx-vision#ParanoidX-VLESS
```

## Migration Checklist
- [x] Generate Reality keypair (x25519)
- [x] Create server.json with VLESS+Reality inbound
- [x] Create systemd user service
- [x] Add API handlers to simplex-node main.go
- [x] Add logrotate config
- [x] Test VLESS server listening on :10813
- [x] Test SOCKS5 client on :10810 → VLESS → Reality
- [ ] Retire VMess server (port 10812) after validation
- [ ] Install logrotate config system-wide: `sudo cp scripts/logrotate-simplex-node /etc/logrotate.d/simplex-node`

## Troubleshooting

### Port 443 Permission Denied
VLESS server initially tried :443 (requires root). Changed to :10813 (user port).

### Reality Handshake Fails
- Check PublicKey matches between client/server
- Check ShortId matches
- Check SNI (www.microsoft.com) resolves and accepts TLS
- Verify xray version supports Reality (26.3.27+)

### Systemd Service Not Starting
```bash
# Check logs
journalctl --user -u vless-server -f

# Check config syntax
/home/tomas/bin/v2ray/xray run -c ~/.local/share/simplex-node/vless/server.json -test

# Manual start for debugging
/home/tomas/bin/v2ray/xray run -c ~/.local/share/simplex-node/vless/server.json
```

### Auto-Init Not Triggered
In `InitVLESS()`, verify:
- `setup-vless.sh` exists at `~/simplex-node/scripts/setup-vless.sh`
- Script is executable (`chmod +x`)
- `HOME` env var set correctly in systemd context

## Deprecation Notes
- **VMess is insecure**: no forward secrecy, fingerprintable
- **VLESS+Reality**: mimics TLS to www.microsoft.com:443, no plaintext fingerprints
- **ShortIds**: random 8-byte prefix per connection
- **XTLS-RPRX-Vision**: flow control for better performance
- **Do NOT run Xray as root** — bind to >1024 ports instead

## ParanoidX Proxy Chain Update
Old: V2Ray(VMess) → Tor → SimpleX → VPN
New: VLESS+Reality → Tor → SimpleX → VPN

The `internal/paranoidx/bridge.go` implements the 4-layer chain routing logic.