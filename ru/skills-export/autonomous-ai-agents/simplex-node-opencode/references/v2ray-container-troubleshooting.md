# V2Ray Docker Container Troubleshooting

## Container Identity
- **Name**: `simplex-node-v2ray`
- **Image**: `v2fly/v2fly-core:latest`
- **Command**: `run -c /etc/v2ray/config.json`
- **Mount**: `Host /home/tomas/simplex-node/docker/v2ray/` → `Container /etc/v2ray/`
- **Port**: 10808 (SOCKS5), 10809 (HTTP)
- **Network**: `simplex-node_default` (docker-compose network)

## Diagnosis Commands

```bash
# Container logs — check startup failure
docker logs simplex-node-v2ray --tail 20

# Check if container is restarting
docker ps --filter name=simplex-node-v2ray --format "{{.Status}}"

# Check mounted volume contents
ls -la /home/tomas/simplex-node/docker/v2ray/

# Check host directory ownership
stat /home/tomas/simplex-node/docker/v2ray/

# Check ParanoidX layer status
curl -s http://127.0.0.1:8080/api/paranoidx/status | python3 -m json.tool

# Verify port reachability
curl -s --socks5 127.0.0.1:10808 http://httpbin.org/ip || echo "10808 not reachable"
```

## Failure Patterns

### Pattern 1: config.json Missing
**Logs**: `fail to load /etc/v2ray/config.json: no such file or directory`
**Cause**: Mounted host directory is empty. File was deleted or never created.
**Fix**:
```bash
# Write config to mounted directory
cat > /home/tomas/simplex-node/docker/v2ray/config.json << 'EOF'
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {"port": 10808, "protocol": "socks", "settings": {"auth": "noauth", "udp": true, "ip": "0.0.0.0"}, "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}},
    {"port": 10809, "protocol": "http", "settings": {"timeout": 0}, "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}}
  ],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF
docker restart simplex-node-v2ray
```

### Pattern 2: Directory Owned by Root
**Issue**: If `docker/v2ray/` is `root:root`, agent tools can't write to it.
**Verification**: `ls -la /home/tomas/simplex-node/docker/v2ray/` shows `drwxr-xr-x 2 root root`
**Requires sudo** (password: BabaYaga99):
```bash
# This needs user approval for sudo
sudo chown -R tomas:tomas /home/tomas/simplex-node/docker/v2ray/
```

### Pattern 3: Port Conflict
**Issue**: Port 10808 already in use by docker-proxy or another process.
**Check**: `ss -tlnp | grep :10808`
**Fix**: `docker stop simplex-node-v2ray && docker rm simplex-node-v2ray && docker compose -f /home/tomas/simplex-node/docker/docker-compose.yml up -d v2ray`

## ParanoidX Layer Architecture

```
Layer       Port    Protocol    Transport                     Status
──────      ────    ────────    ─────────                     ──────
v2ray       10808   SOCKS5      Docker container              🟢/🔴
vmess       10812   VMESS       Native xray process           🟢/🔴
vless       10813   VLESS+Reality Native xray process         🟢/🔴
tor         9050    SOCKS5      Docker container/external     🟢/🔴
simplex     17225   SimpleX     Docker container              🟢/🔴
```

The ParanoidX chain is: `App → V2Ray(10808) → VMess(10812) → VLESS(10813) → Tor(9050) → SimpleX(17225)`
If any layer is unhealthy, the chain is broken.