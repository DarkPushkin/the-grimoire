#!/usr/bin/env bash
#
# bootstrap.sh — Hermes Agent bootstrap for new Linux machines
#
# Purpose:
#   Idempotent one-shot that sets up Hermes Agent, configures Telegram
#   authentication, creates the ~/simplex-node project scaffold, and
#   provisions an SSH key if none exists.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../bootstrap.sh | bash
#   # or locally:
#   bash bootstrap.sh
#
set -euo pipefail

# ──────────────────────────────────────────────
# Color helpers
# ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ──────────────────────────────────────────────
# Step 0 — Detect OS / distro
# ──────────────────────────────────────────────
detect_package_manager() {
  if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt-get"
    PKG_INSTALL="apt-get install -y"
    PKG_UPDATE="apt-get update -qq"
  elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    PKG_INSTALL="dnf install -y"
    PKG_UPDATE="dnf check-update || true"
  elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
    PKG_INSTALL="yum install -y"
    PKG_UPDATE="yum check-update || true"
  elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
    PKG_INSTALL="pacman -S --noconfirm"
    PKG_UPDATE="pacman -Sy"
  elif command -v zypper &>/dev/null; then
    PKG_MANAGER="zypper"
    PKG_INSTALL="zypper install -y"
    PKG_UPDATE="zypper refresh"
  else
    err "Unsupported package manager. Please install curl, git, and build-essential manually."
    exit 1
  fi
}

# ──────────────────────────────────────────────
# Step 1 — Install system dependencies
# ──────────────────────────────────────────────
install_system_deps() {
  info "Installing system dependencies (curl, git, build-essential)..."

  # Different distros call the build-essential bundle differently
  local build_pkg=""
  case "$PKG_MANAGER" in
    apt-get)  build_pkg="build-essential" ;;
    dnf|yum)  build_pkg="@development-tools" ;;
    pacman)   build_pkg="base-devel" ;;
    zypper)   build_pkg="patterns-devel-base-devel_basis" ;;
  esac

  # Update package lists (idempotent — safe to run repeatedly)
  $PKG_UPDATE

  # Install — idempotent by nature (package managers skip already-installed)
  $PKG_INSTALL curl git "$build_pkg"

  ok "System dependencies installed."
}

# ──────────────────────────────────────────────
# Step 2 — Install / verify Hermes Agent
# ──────────────────────────────────────────────
install_hermes() {
  if command -v hermes &>/dev/null; then
    ok "Hermes Agent is already installed ($(hermes --version 2>/dev/null || echo 'version unknown'))."
    return
  fi

  info "Hermes Agent not found — installing..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

  if ! command -v hermes &>/dev/null; then
    err "Hermes installation finished but 'hermes' is not on PATH."
    err "Try restarting your shell or adding ~/.local/bin to PATH."
    exit 1
  fi

  ok "Hermes Agent installed."
}

# ──────────────────────────────────────────────
# Step 3 — Configure Telegram bot token
# ──────────────────────────────────────────────
configure_telegram_token() {
  # Check if already configured
  if hermes config get telegram.token &>/dev/null 2>&1; then
    local current_token
    current_token="$(hermes config get telegram.token 2>/dev/null || true)"
    if [ -n "$current_token" ]; then
      ok "Telegram bot token is already configured."
      return
    fi
  fi

  echo ""
  warn "─────────────────────────────────────────────────────"
  warn " Telegram Bot Token Required"
  warn "─────────────────────────────────────────────────────"
  echo ""
  echo "To get a token:"
  echo "  1. Open Telegram and search for @BotFather"
  echo "  2. Send /newbot and follow the prompts"
  echo "  3. Copy the HTTP API token (looks like: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11)"
  echo ""
  echo -n "Enter your Telegram bot token: "
  read -r TELEGRAM_TOKEN

  if [ -z "$TELEGRAM_TOKEN" ]; then
    warn "No token entered — skipping Telegram configuration."
    warn "Set it later with: hermes config set telegram.token YOUR_TOKEN"
    return
  fi

  hermes config set telegram.token "$TELEGRAM_TOKEN"
  ok "Telegram bot token saved."
}

# ──────────────────────────────────────────────
# Step 4 — Set approvals mode to manual
# ──────────────────────────────────────────────
configure_approvals() {
  local current_mode
  current_mode="$(hermes config get approvals.mode 2>/dev/null || echo "")"

  if [ "$current_mode" = "manual" ]; then
    ok "Approvals mode is already set to 'manual'."
    return
  fi

  info "Setting approvals mode to 'manual'..."
  hermes config set approvals.mode manual
  ok "Approvals mode set to 'manual'."
}

# ──────────────────────────────────────────────
# Step 5 — Create ~/simplex-node project structure
# ──────────────────────────────────────────────
create_simplex_node_structure() {
  local base_dir="$HOME/simplex-node"

  if [ -d "$base_dir" ]; then
    ok "~/simplex-node already exists — skipping creation."
  else
    info "Creating ~/simplex-node project structure..."
    mkdir -p "$base_dir"/{scripts,config,data,logs}
    info "Created: $base_dir"
    info "         $base_dir/scripts/"
    info "         $base_dir/config/"
    info "         $base_dir/data/"
    info "         $base_dir/logs/"
    ok "~/simplex-node structure created."
  fi
}

# ──────────────────────────────────────────────
# Step 6 — Generate SSH key if missing
# ──────────────────────────────────────────────
ensure_ssh_key() {
  local key_type="${1:-ed25519}"
  local key_path="$HOME/.ssh/id_${key_type}"

  # Ensure ~/.ssh exists with correct permissions
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [ -f "$key_path" ]; then
    ok "SSH key exists: $key_path"
  else
    info "No SSH key found — generating ${key_type} key..."

    # Use a default comment so the user knows which machine generated it
    local comment="evolution-protocol@$(hostname)"

    ssh-keygen -t "$key_type" -f "$key_path" -C "$comment" -N "" 2>&1

    # Add to ssh-agent if available
    if command -v ssh-agent &>/dev/null; then
      eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
      ssh-add "$key_path" 2>/dev/null || warn "Could not add key to ssh-agent."
    fi

    ok "SSH key generated: $key_path"
    echo ""
    echo "  Public key:"
    cat "${key_path}.pub"
    echo ""
    warn "Add this public key to GitHub / GitLab / your server before using SSH."
  fi
}

# ──────────────────────────────────────────────
# Step 7 — Print setup-complete banner
# ──────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${GREEN}┌─────────────────────────────────────────────────────────┐${NC}"
  echo -e "${GREEN}│${NC}                                                         ${GREEN}│${NC}"
  echo -e "${GREEN}│${NC}  ${CYAN}✨ Evolution Protocol — Bootstrap Complete${NC}         ${GREEN}│${NC}"
  echo -e "${GREEN}│${NC}                                                         ${GREEN}│${NC}"
  echo -e "${GREEN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""

  echo -e "${CYAN}What was done:${NC}"
  echo "  ✅ System dependencies (curl, git, build-essential)"
  echo "  ✅ Hermes Agent installed / verified"
  echo "  ✅ Telegram bot token configured"
  echo "  ✅ approvals.mode = manual"
  echo "  ✅ ~/simplex-node/ structure created"
  echo "  ✅ SSH key checked / generated"
  echo ""

  echo -e "${CYAN}What to do next:${NC}"
  echo ""
  echo "  1. ${YELLOW}Start Hermes:${NC}        hermes start"
  echo ""
  echo "  2. ${YELLOW}Check config:${NC}        hermes config list"
  echo ""
  echo "  3. ${YELLOW}Verify Telegram:${NC}     Send /ping to your bot on Telegram"
  echo ""
  echo "  4. ${YELLOW}Edit profile:${NC}        hermes config set profile.default \"your-profile\""
  echo ""
  echo "  5. ${YELLOW}Simplex node:${NC}        cd ~/simplex-node && ls -la"
  echo ""
  echo "  6. ${YELLOW}SSH public key:${NC}      cat ~/.ssh/id_ed25519.pub"
  echo "                             (or id_rsa.pub if using RSA)"
  echo ""
  echo "  7. ${YELLOW}Install plugins:${NC}     hermes plugin list"
  echo ""
  echo "  8. ${YELLOW}Read the docs:${NC}       https://hermes-agent.nousresearch.com/docs"
  echo ""

  # Only show if key was generated
  if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo -e "${CYAN}Your SSH public key (copy this to GitHub/GitLab):${NC}"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
  fi

  echo -e "${GREEN}Bootstrap complete — happy building!${NC}"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
main() {
  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC}                                                         ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  Evolution Protocol — Hermes Agent Bootstrap            ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}                                                         ${CYAN}│${NC}"
  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""

  detect_package_manager

  install_system_deps
  install_hermes
  configure_telegram_token
  configure_approvals
  create_simplex_node_structure
  ensure_ssh_key
  print_summary
}

main "$@"