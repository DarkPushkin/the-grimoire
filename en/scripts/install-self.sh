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

# ── 1. Clone / pull ──────────────────────────────────────────────────────────
if [[ -d "${TARGET}/.git" ]]; then
  echo "→ grimoire already cloned at ${TARGET}, pulling..."
  git -C "${TARGET}" pull --ff-only origin "${BRANCH}" 2>/dev/null || true
  SRC="${TARGET}"
else
  echo "→ cloning ${REPO}..."
  git clone --depth 1 --branch "${BRANCH}" "https://github.com/${REPO}.git" "${WORK}/grimoire"
  SRC="${WORK}/grimoire"
fi

if [[ ! -d "${SRC}/en/skills" ]]; then
  echo "❌ ${SRC}/en/skills not found — wrong repo or branch?"
  exit 1
fi

# ── 2. Install skills ────────────────────────────────────────────────────────
mkdir -p "${TARGET}"
COUNT=0
for skilldir in "${SRC}"/en/skills/*/; do
  [[ -d "$skilldir" ]] || continue
  name="$(basename "$skilldir")"
  if [[ -f "${skilldir}/SKILL.md" ]]; then
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
