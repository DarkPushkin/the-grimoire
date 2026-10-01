#!/usr/bin/env bash
# ============================================================================
# verify-grimoire.sh — does the host still match the grimoire?
# ============================================================================
#
# CI check / health probe. Clones the grimoire into a temp dir, runs
# install-v2.sh against an ISOLATED target (never touches ~/.hermes/skills),
# and verifies the result:
#
#   - every skill in the grimoire lands in the isolated target
#   - every SKILL.md matches the grimoire byte-for-byte
#   - every SKILL.md has a valid name: in its frontmatter
#
# Exits non-zero on any drift. Safe to run on a live host: it writes only to
# a temp dir and removes it on exit.
#
# Usage:
#   bash verify-grimoire.sh                    # verify against this repo
#   bash verify-grimoire.sh --repo owner/name  # verify against a fork/branch
#   bash verify-grimoire.sh --local-only       # skip the clone, use $SRC
#
# Exit: 0 ok | 1 setup error | 2 verification failed
# ============================================================================
set -euo pipefail

REPO="DarkPushkin/the-grimoire"
BRANCH="main"
LOCAL_ONLY=0
SRC=""
WORK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)       REPO="$2"; shift 2 ;;
    --branch)     BRANCH="$2"; shift 2 ;;
    --local-only) LOCAL_ONLY=1; shift ;;
    -h|--help)    sed -n '3,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi
info() { echo "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo "${GREEN}[OK]${NC}    $*"; }
warn() { echo "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo "${RED}[FAIL]${NC}  $*"; }

cleanup() { [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"; return 0; }
trap cleanup EXIT

strip_proxy() {
  env -u http_proxy -u https_proxy -u all_proxy -u ALL_PROXY \
      -u HTTP_PROXY -u HTTPS_PROXY -u no_proxy -u NO_PROXY "$@"
}

# Locate this repo when run from inside a checkout.
# SCRIPTS_DIR = <repo>/en/scripts ; REPO_ROOT = <repo>
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPTS_DIR")")"

if [[ -d "${REPO_ROOT}/en/skills" ]]; then
  SRC="$REPO_ROOT"
  info "verifying this checkout: ${SRC}"
else
  SRC=""
  if [[ $LOCAL_ONLY -eq 1 ]]; then
    err "--local-only given but no grimoire checkout found"
    err "  looked for en/skills under: ${REPO_ROOT}"
    err "  run from inside the repo, or drop --local-only to clone ${REPO}"
    exit 1
  fi
  WORK="$(mktemp -d /tmp/grimoire-verify.XXXXXX)"
  SRC="${WORK}/grimoire"
  info "cloning ${REPO} (proxy stripped)..."
  strip_proxy git clone --depth 1 --branch "$BRANCH" \
    "https://github.com/${REPO}.git" "$SRC" >/dev/null 2>&1 \
    || { err "clone failed"; exit 1; }
  ok "cloned"
fi

# ALWAYS use a private work dir for the target, even when SRC is a local
# checkout. A shared/fixed target path would accumulate state between runs and
# make results depend on previous invocations.
WORK="${WORK:-$(mktemp -d /tmp/grimoire-verify.XXXXXX)}"
TARGET="${WORK}/target"
REPORT="${WORK}/install-report.md"
DIFF_OUT="${WORK}/hashdiff.txt"
mkdir -p "$TARGET"

echo
info "1/3 installing into isolated target..."
INSTALLER="${SRC}/en/scripts/install-v2.sh"
[[ -f "$INSTALLER" ]] || INSTALLER="$(dirname "${BASH_SOURCE[0]}")/install-v2.sh"

if [[ -f "$INSTALLER" ]]; then
  strip_proxy bash "$INSTALLER" --from "$SRC" --target "$TARGET" --loot-only \
    --report "$REPORT" >/dev/null 2>&1 \
    || RC=$?
  RC=${RC:-0}
  if [[ $RC -ne 0 ]]; then
    err "installer exited ${RC}"
    [[ $RC -eq 3 ]] && err "  (3 = drift detected inside the isolated install)"
    exit "$RC"
  fi
  ok "install completed"
else
  warn "install-v2.sh not found - falling back to manual copy"
  cp -r "${SRC}/en/skills/." "$TARGET/"
fi

echo
info "2/3 verifying skill count..."
SRC_N=$(find "${SRC}/en/skills" -name SKILL.md | wc -l)
TGT_N=$(find "$TARGET" -name SKILL.md | wc -l)
info "grimoire: ${SRC_N}   target: ${TGT_N}"
if [[ "$TGT_N" -ne "$SRC_N" ]]; then
  err "count mismatch: ${SRC_N} != ${TGT_N}"
  exit 2
fi
ok "count matches (${SRC_N})"

echo
info "3/3 verifying content hashes and frontmatter..."
# SRC_SKILLS_ROOT = <grimoire>/en/skills ; TARGET mirrors the same
# category/skill relative layout, so compare by relative path (basenames
# collide across categories).
python3 - "${SRC}/en/skills" "$TARGET" > "$DIFF_OUT" <<'PYEOF'
import hashlib, os, sys
src, tgt = sys.argv[1], sys.argv[2]

def skills(root):
    out = []
    for d, _, files in os.walk(root):
        if "SKILL.md" in files:
            out.append(os.path.join(d, "SKILL.md"))
    return sorted(out)

def sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()

src_sk, tgt_sk = skills(src), skills(tgt)
tgt_by_rel = {os.path.relpath(p, tgt): p for p in tgt_sk}

missing, mismatched, badfm = [], [], []
for p in src_sk:
    rel = os.path.relpath(p, src)
    c = tgt_by_rel.get(rel)
    if c is None:
        missing.append(rel); continue
    if sha(p) != sha(c):
        mismatched.append(rel)
    head = open(p, encoding="utf-8", errors="replace").read(500)
    if not head.lstrip().startswith("---") or "\nname:" not in head:
        badfm.append(rel)

for rel in missing:    print(f"MISSING\t{rel}")
for rel in mismatched: print(f"HASH\t{rel}")
for rel in badfm:      print(f"FRONTMATTER\t{rel}")
print(f"SUMMARY\tsrc={len(src_sk)}\tmissing={len(missing)}\thash={len(mismatched)}\tfm={len(badfm)}")
PYEOF

SUMMARY="$(grep '^SUMMARY' "$DIFF_OUT" | head -1 || true)"
echo "  ${SUMMARY#SUMMARY	}"

if grep -qE '^(MISSING|HASH|FRONTMATTER)' "$DIFF_OUT"; then
  err "content mismatches found:"
  grep -E '^(MISSING|HASH|FRONTMATTER)' "$DIFF_OUT" | head -15 | sed 's/^/     /'
  exit 2
fi

ok "all ${SRC_N} skills match the grimoire byte-for-byte"
ok "all frontmatter valid"

echo
ok "✅ grimoire is consistent - host can be reproduced from it"
exit 0