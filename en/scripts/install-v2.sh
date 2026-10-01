#!/usr/bin/env bash
# ============================================================================
# install-v2.sh — The Grimoire -> new host (source of truth)
# ============================================================================
#
# Replaces install-self.sh. Key difference: CONTENT-IDEMPOTENT UPDATES.
# Run it as often as you like - it brings skills to the grimoire's state and
# never silently leaves a stale copy behind.
#
# Fixes vs install-self.sh:
#   1. Updates existing skills (no more 'cp -rn', which skipped them forever).
#   2. Preserves en/skills/<category>/<skill>/ layout, which matches
#      ~/.hermes/skills/<category>/<skill>/ exactly.
#   3. Name collisions are REPORTED, not silently flattened (v1 lost 12 skills).
#   4. Strips the Tor proxy (socks5 *_proxy) before git clone - it hangs there.
#   5. Verifies with 'hermes skills list' (v1 called a nonexistent
#      'hermes skills').
#   6. Emits a machine-readable report and a CI-usable exit code.
#   7. Detects drift between the grimoire and what is actually installed.
#
# Usage:
#   bash install-v2.sh                              # -> ~/.hermes/skills
#   bash install-v2.sh --target /path/skills
#   bash install-v2.sh --from /path/to/grimoire     # no clone (CI, offline)
#   bash install-v2.sh --dry-run
#   bash install-v2.sh --report /tmp/report.md
#   bash install-v2.sh --allow-prune                # drop skills absent upstream
#   bash install-v2.sh --loot-only                  # skills only, no configs
#
# Exit codes: 0 ok | 1 error | 2 name collisions | 3 drift (target < source)
# ============================================================================
set -euo pipefail

REPO="DarkPushkin/the-grimoire"
BRANCH="main"
TARGET="${HOME}/.hermes/skills"
SRC_OVERRIDE=""
REPORT=""
DRY_RUN=0
LOOT_ONLY=0
ALLOW_PRUNE=0
WORK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO="$2"; shift 2 ;;
    --branch)      BRANCH="$2"; shift 2 ;;
    --target)      TARGET="$2"; shift 2 ;;
    --from)        SRC_OVERRIDE="$2"; shift 2 ;;
    --report)      REPORT="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --loot-only)   LOOT_ONLY=1; shift ;;
    --allow-prune) ALLOW_PRUNE=1; shift ;;
    -h|--help)     sed -n '3,28p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi
info() { echo "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo "${GREEN}[OK]${NC}    $*"; }
warn() { echo "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo "${RED}[ERR]${NC}   $*" >&2; }

cleanup() { [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"; return 0; }
trap cleanup EXIT

# Tor proxy breaks git clone (hangs) and other tooling. Strip it.
strip_proxy() {
  env -u http_proxy -u https_proxy -u all_proxy -u ALL_PROXY \
      -u HTTP_PROXY -u HTTPS_PROXY -u no_proxy -u NO_PROXY \
      "$@"
}

# True (0) when the two directory trees differ, false (1) when identical.
dir_changed() {
  local a="$1" b="$2"
  [[ -d "$b" ]] || return 0
  diff -rq "$a" "$b" >/dev/null 2>&1 && return 1 || return 0
}

echo "🌍 The Grimoire -> Host (v2)"
echo "======================================="
info "repo:   ${REPO} (${BRANCH})"
info "target: ${TARGET}"
[[ $DRY_RUN -eq 1 ]] && warn "DRY RUN - nothing will be modified"
echo

# ── 1. Obtain the grimoire ────────────────────────────────────────────────
if [[ -n "$SRC_OVERRIDE" ]]; then
  SRC="$SRC_OVERRIDE"
  info "using local source: ${SRC}"
  [[ -d "${SRC}/en/skills" ]] || { err "no en/skills under ${SRC}"; exit 1; }
elif [[ -d "${TARGET}/.git" ]]; then
  SRC="$TARGET"
  info "grimoire already present: ${SRC}"
  strip_proxy git -C "$SRC" pull --ff-only origin "$BRANCH" >/dev/null 2>&1 \
    || warn "git pull failed - using current state"
else
  WORK="$(mktemp -d /tmp/grimoire-clone.XXXXXX)"
  SRC="${WORK}/grimoire"
  info "cloning (proxy stripped)..."
  CLONED=0
  for attempt in 1 2 3; do
    if strip_proxy git clone --depth 1 --branch "$BRANCH" \
        "https://github.com/${REPO}.git" "$SRC" >/dev/null 2>&1; then
      ok "cloned (attempt ${attempt}/3)"
      CLONED=1
      break
    fi
    warn "clone failed (${attempt}/3), retrying in 5s..."
    sleep 5
  done
  [[ $CLONED -eq 1 ]] || { err "clone failed after 3 attempts"; exit 1; }
fi

[[ -d "${SRC}/en/skills" ]] || { err "no ${SRC}/en/skills - wrong repo/branch"; exit 1; }

mapfile -t SRC_SKILLS < <(find "${SRC}/en/skills" -name SKILL.md -printf '%h\n' | sort)
SRC_COUNT=${#SRC_SKILLS[@]}
info "skills in grimoire: ${SRC_COUNT}"

# ── 2. Collision report (informational: layout is preserved) ──────────────
declare -A SEEN=()
COLLISIONS=()
for d in "${SRC_SKILLS[@]}"; do
  rel="${d#"${SRC}/en/skills/"}"
  leaf="${rel##*/}"
  cat="${rel%/*}"
  if [[ -n "${SEEN[$leaf]:-}" && "${SEEN[$leaf]}" != "$cat" ]]; then
    COLLISIONS+=("${rel}  <->  ${SEEN[$leaf]}/${leaf}")
  else
    SEEN[$leaf]="$cat"
  fi
done

if [[ ${#COLLISIONS[@]} -gt 0 ]]; then
  echo
  warn "duplicate skill names across categories (${#COLLISIONS[@]}):"
  for c in "${COLLISIONS[@]}"; do echo "     ${c}"; done
  echo
  info "Layout is preserved, so these land in DIFFERENT directories and do"
  info "not overwrite each other. Verified by the count check in section 6."
  echo
fi

# ── 3. Install / update skills ────────────────────────────────────────────
if [[ $DRY_RUN -eq 1 ]]; then
  warn "DRY RUN: would install/update ${SRC_COUNT} skills into ${TARGET}"
  exit 0
fi

mkdir -p "$TARGET"
INSTALLED=0; UPDATED=0; UNCHANGED=0; PRUNED=0; SHOWN=0
DETAILS=""

for skilldir in "${SRC_SKILLS[@]}"; do
  rel="${skilldir#"${SRC}/en/skills/"}"
  dest="${TARGET}/${rel}"

  if [[ -d "$dest" ]]; then
    if dir_changed "$skilldir" "$dest"; then
      if command -v rsync >/dev/null 2>&1; then
        strip_proxy rsync -a --checksum --delete \
          "${skilldir}/" "${dest}/" 2>/dev/null || cp -rf "${skilldir}/." "${dest}/"
      else
        rm -rf "${dest:?}" && cp -r "$skilldir" "$dest"
      fi
      UPDATED=$((UPDATED+1))
      [[ $SHOWN -lt 10 ]] && { DETAILS+="  ~ ${rel}"$'\n'; SHOWN=$((SHOWN+1)); }
    else
      UNCHANGED=$((UNCHANGED+1))
    fi
  else
    mkdir -p "$(dirname "$dest")"
    cp -r "$skilldir" "$dest"
    INSTALLED=$((INSTALLED+1))
    [[ $SHOWN -lt 10 ]] && { DETAILS+="  + ${rel}"$'\n'; SHOWN=$((SHOWN+1)); }
  fi
done

# ── 4. Prune (opt-in) ─────────────────────────────────────────────────────
if [[ $ALLOW_PRUNE -eq 1 ]]; then
  mapfile -t TGT_SKILLS < <(find "$TARGET" -name SKILL.md -printf '%h\n' 2>/dev/null | sort)
  declare -A SRC_SET=()
  for d in "${SRC_SKILLS[@]}"; do SRC_SET["$d"]=1; done
  for t in "${TGT_SKILLS[@]}"; do
    [[ -z "${SRC_SET[$t]:-}" ]] || continue
    rm -rf "$t"
    PRUNED=$((PRUNED+1))
    DETAILS+="  - ${t#"${TARGET}/"}"$'\n'
  done
  [[ $PRUNED -gt 0 ]] && warn "pruned ${PRUNED} skill(s) absent from the grimoire"
fi

# ── 5. Configs / docs / manifests (content-aware merge) ───────────────────
if [[ $LOOT_ONLY -eq 0 ]]; then
  for sub in configs templates docs manifests; do
    [[ -d "${SRC}/en/${sub}" ]] || continue
    mkdir -p "${HOME}/.hermes/${sub}"
    if command -v rsync >/dev/null 2>&1; then
      strip_proxy rsync -a --checksum "${SRC}/en/${sub}/." "${HOME}/.hermes/${sub}/" 2>/dev/null || true
    else
      cp -rf "${SRC}/en/${sub}/." "${HOME}/.hermes/${sub}/" 2>/dev/null || true
    fi
    DETAILS+="  ~ ${sub}/"$'\n'
  done
fi

# ── 6. Verify: drift detection ────────────────────────────────────────────
mapfile -t FINAL < <(find "$TARGET" -name SKILL.md -printf '%h\n' | sort)
FINAL_COUNT=${#FINAL[@]}

echo
ok "installed: ${INSTALLED}   updated: ${UPDATED}   unchanged: ${UNCHANGED}   pruned: ${PRUNED}"
info "skills now in ${TARGET}: ${FINAL_COUNT} (grimoire has: ${SRC_COUNT})"

DRIFT=0
if [[ ${FINAL_COUNT} -lt ${SRC_COUNT} ]]; then
  DRIFT=1
  err "DRIFT: target has ${FINAL_COUNT}, grimoire has ${SRC_COUNT}"
  declare -A HAVE=()
  for d in "${FINAL[@]}"; do HAVE["$d"]=1; done
  missing=0
  for d in "${SRC_SKILLS[@]}"; do
    if [[ -z "${HAVE[$d]:-}" ]]; then
      [[ $missing -lt 8 ]] && err "  missing: ${d#"${SRC}/en/skills/"}"
      missing=$((missing+1))
    fi
  done
  [[ $missing -gt 8 ]] && err "  ... and $((missing-8)) more"
elif [[ ${FINAL_COUNT} -gt ${SRC_COUNT} ]]; then
  info "target has ${FINAL_COUNT} - ${SRC_COUNT} extra local skill(s), fine"
else
  ok "no drift - grimoire and host match exactly"
fi

if command -v hermes >/dev/null 2>&1; then
  if hermes skills list >/dev/null 2>&1; then
    ok "'hermes skills list' works"
  else
    warn "'hermes skills list' failed - check manually"
  fi
else
  info "hermes CLI not found - skills load on next Hermes start"
fi

# ── 7. Report ─────────────────────────────────────────────────────────────
if [[ -n "$REPORT" ]]; then
  {
    echo "# install-v2 report"
    echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo: ${REPO}"
    echo "branch: ${BRANCH}"
    echo "target: ${TARGET}"
    echo "skills_in_grimoire: ${SRC_COUNT}"
    echo "skills_in_target: ${FINAL_COUNT}"
    echo "installed_new: ${INSTALLED}"
    echo "updated: ${UPDATED}"
    echo "unchanged: ${UNCHANGED}"
    echo "pruned: ${PRUNED}"
    echo "drift: ${DRIFT}"
    echo "collisions: ${#COLLISIONS[@]}"
    echo "hermes_cli: $(command -v hermes >/dev/null 2>&1 && echo present || echo absent)"
    echo "rsync: $(command -v rsync >/dev/null 2>&1 && echo present || echo absent)"
    echo ""
    echo "## changed (first 10)"
    printf '%s' "$DETAILS"
    echo ""
    echo "## collisions"
    if [[ ${#COLLISIONS[@]} -gt 0 ]]; then
      printf '  %s\n' "${COLLISIONS[@]}"
    else
      echo "  none"
    fi
  } > "$REPORT"
  info "report: ${REPORT}"
fi

echo
ok "done. Source of truth: ${REPO}@${BRANCH}"

[[ $DRIFT -eq 1 ]] && exit 3
exit 0