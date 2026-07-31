#!/usr/bin/env bash
# ============================================================================
# install-self.sh — Hermes Agent self-replication / decentralized evolution
# ============================================================================
# Clones The Grimoire (the skill library) from GitHub and installs all skills
# into a fresh Hermes Agent installation. Run this on ANY new machine to
# bootstrap the full skill set — the agent "clones itself" from the book.
#
# Usage:
#   bash install-self.sh [--repo DarkPushkin/the-grimoire] [--branch main]
#                        [--target ~/.hermes/skills] [--loot-only]
#
# What it does:
#   1. Clones (or pulls) the-grimoire from GitHub
#   2. Copies every skill into the Hermes skills directory (~/.hermes/skills)
#   3. Copies configs/templates/docs into ~/.hermes/ (non-destructive merge)
#   4. Prints an inventory of installed skills
#
# Requirements: git, bash. Optional: hermes (to verify skill loading).
# ============================================================================
set -euo pipefail

REPO="DarkPushkin/the-grimoire"
BRANCH="main"
TARGET="${HOME}/.hermes/skills"
WORK="$(mktemp -d /tmp/grimoire-clone.XXXXXX)"
LOOT_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --loot-only) LOOT_ONLY=1; shift ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

echo "🌍 Hermes Self-Replication"
echo "=========================="
echo "  repo:   ${REPO} (${BRANCH})"
echo "  target: ${TARGET}"

# ── 1. Clone / pull (with retry — the grimoire is ~28MB and flaky channels drop it) ──
clone_with_retry() {
  local dest="$1" attempt=0
  while [[ $attempt -lt 4 ]]; do
    attempt=$((attempt+1))
    echo "→ cloning ${REPO} (attempt ${attempt}/4)..."
    git config --global http.postBuffer 524288000 || true
    git clone --depth 1 --branch "${BRANCH}" "https://github.com/${REPO}.git" "${dest}" 2>&1 | tail -3 && return 0
    echo "  clone failed, retrying in 5s..."
    sleep 5
  done
  return 1
}

if [[ -d "${TARGET}/.git" ]]; then
  echo "→ grimoire already cloned at ${TARGET}, pulling..."
  git -C "${TARGET}" pull --ff-only origin "${BRANCH}" 2>/dev/null || true
  SRC="${TARGET}"
else
  clone_with_retry "${WORK}/grimoire" || { echo "❌ could not clone after 4 attempts"; exit 1; }
  SRC="${WORK}/grimoire"
fi

if [[ ! -d "${SRC}/en/skills" ]]; then
  echo "❌ ${SRC}/en/skills not found — wrong repo or branch?"
  exit 1
fi

# ── 2. Install skills (recursive — SKILL.md can be nested in collections) ────
mkdir -p "${TARGET}"
COUNT=0
# Top-level skill dirs
for skilldir in "${SRC}"/en/skills/*/; do
  [[ -d "$skilldir" ]] || continue
  name="$(basename "$skilldir")"
  if [[ -f "${skilldir}/SKILL.md" ]]; then
    cp -r "$skilldir" "${TARGET}/${name}" 2>/dev/null || true
    COUNT=$((COUNT+1))
  fi
done
# Nested collections (composio/, super-hermes/, tencentdb-agent-memory/, ...)
for skillfile in $(find "${SRC}"/en/skills -name "SKILL.md" 2>/dev/null); do
  skilldir="$(dirname "$skillfile")"
  name="$(basename "$skilldir")"
  if [[ ! -e "${TARGET}/${name}" && -f "${skilldir}/SKILL.md" ]]; then
    cp -r "$skilldir" "${TARGET}/${name}" 2>/dev/null || true
    COUNT=$((COUNT+1))
  fi
done

# ── 3. Non-destructive merge of configs / templates / docs ───────────────────
if [[ "${LOOT_ONLY}" -eq 0 ]]; then
  for sub in configs templates docs manifests; do
    if [[ -d "${SRC}/en/${sub}" ]]; then
      mkdir -p "${HOME}/.hermes/${sub}"
      cp -rn "${SRC}/en/${sub}/." "${HOME}/.hermes/${sub}/" 2>/dev/null || true
    fi
  done
fi

rm -rf "${WORK}"

# ── 4. Inventory ─────────────────────────────────────────────────────────────
echo ""
echo "✅ Installed ${COUNT} skills into ${TARGET}"
echo ""
if command -v hermes >/dev/null 2>&1; then
  echo "→ verifying with hermes skills..."
  hermes skills 2>/dev/null | head -10 || echo "  (run 'hermes skills' to browse)"
else
  echo "ℹ️  hermes CLI not found — skills will load on next Hermes start"
fi

echo ""
echo "🎉 Self-replication complete. The Grimoire lives on: ${REPO}"
echo "   'Код — это живое произведение искусства, которое эволюционирует.'"
