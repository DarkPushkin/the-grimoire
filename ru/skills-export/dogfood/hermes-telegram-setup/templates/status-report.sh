#!/usr/bin/env bash
# Status report for Hermes Telegram cron delivery
# Place at ~/.hermes/scripts/status-report.sh

set -euo pipefail

# ── System Status ──
UPTIME=$(uptime -p | sed 's/up //')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
MEM=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
SWAP=$(free -h | awk '/^Swap:/ {print $3 "/" $2}')
TOR=$(systemctl --user is-active tor 2>/dev/null || systemctl is-active tor 2>/dev/null || echo "unknown")

# ── Hermes Gateway ──
GATEWAY_PID=$(pgrep -f "hermes_cli.main gateway run" 2>/dev/null || echo "0")
if [ "$GATEWAY_PID" != "0" ]; then
  GATEWAY_CPU=$(ps -p "$GATEWAY_PID" -o %cpu= 2>/dev/null || echo "?")
  GATEWAY_MEM=$(ps -p "$GATEWAY_PID" -o rss= 2>/dev/null | awk '{printf "%.0f MB", $1/1024}' || echo "?")
  GATEWAY_UPTIME=$(ps -o etime= -p "$GATEWAY_PID" 2>/dev/null | xargs || echo "?")
  SESSION_COUNT=$(find /home/tomas/.hermes/sessions -name "*.json" 2>/dev/null | wc -l)
  GATEWAY_STATUS="🟢 Running (PID $GATEWAY_PID, ${GATEWAY_CPU}% CPU, ${GATEWAY_MEM}, up ${GATEWAY_UPTIME})"
  SESSION_INFO="${SESSION_COUNT} session files"
else
  GATEWAY_STATUS="🔴 NOT RUNNING"
  SESSION_INFO="N/A"
fi

# ── Project Status ──
if [ -d /home/tomas/simplex-node ]; then
  cd /home/tomas/simplex-node
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
  GIT_DIRTY=$(git status --porcelain 2>/dev/null | wc -l)
  [ "$GIT_DIRTY" -gt 0 ] && DIRTY_STR="${GIT_DIRTY} modified" || DIRTY_STR="clean"
  DOCKER_RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ' || echo "N/A")
  PROJECT_STATUS="🟢 ${GIT_BRANCH} @ ${GIT_COMMIT} (${DIRTY_STR})"
else
  PROJECT_STATUS="⚠️ Not found"
  DOCKER_RUNNING="N/A"
fi

# ── Report ──
cat <<REPORT
🏰 **Saint Mary Liberty Island — Status Report**
📅 $(date '+%Y-%m-%d %H:%M')

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**🖥 Система**
• Uptime: ${UPTIME}
• Load: ${LOAD}
• Memory: ${MEM}
• Swap: ${SWAP}
• Disk: ${DISK}
• Tor: ${TOR}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**🤖 Hermes Gateway**
${GATEWAY_STATUS}
• Sessions: ${SESSION_INFO}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**🏗 Project: simplex-node**
${PROJECT_STATUS}
• Docker: ${DOCKER_RUNNING:-none}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ **Evolution continues.** *Ad gloriam Dei et libertatem Insulae Sanctae Mariae.*
REPORT