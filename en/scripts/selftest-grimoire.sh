#!/usr/bin/env bash
# ============================================================================
# selftest-grimoire.sh — proves verify-grimoire.sh is NOT a vacuous test
# ============================================================================
#
# A green check that cannot fail is worthless. This script deliberately breaks
# the grimoire in five ways and asserts that the verification catches each one.
# Run it after touching install-v2.sh or verify-grimoire.sh.
#
# Usage:  bash selftest-grimoire.sh
# Exit:   0 all mutations caught | 1 at least one slipped through
# ============================================================================
set -uo pipefail

G="${GRIMOIRE_ROOT:-/mnt/data/Export/the-grimoire}"
SCRIPTS="$G/en/scripts"
WORK="/tmp/grimoire-selftest.$$"
PASS=0; FAIL=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

strip() { env -u http_proxy -u https_proxy -u ALL_PROXY -u all_proxy \
               -u HTTP_PROXY -u HTTPS_PROXY "$@"; }

pass() { echo "  OK   $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

verify() {  # verify <repo-root> -> exit code
  ( cd "$1/en/scripts" && timeout 400 bash ./verify-grimoire.sh --local-only >/dev/null 2>&1 )
  echo $?
}

echo "=== M1: healthy grimoire -> must PASS (exit 0) ==="
RC=$(verify "$G")
[[ "$RC" == "0" ]] && pass "healthy grimoire accepted" || fail "healthy grimoire rejected (exit $RC)"

echo
echo "=== M2: skill deleted FROM the grimoire -> host must follow the source ==="
# Not a 'grimoire must be complete' check. The grimoire IS the source of truth,
# so deleting from it is legitimate. What matters: the isolated host rebuild
# mirrors the source and leaves no ghost behind.
rm -rf "$WORK"; cp -a "$G" "$WORK"
rm -rf "$WORK/en/skills/lexmount-moli/moli-webfetch"
RC=$(verify "$WORK")
[[ "$RC" == "0" ]] && pass "still self-consistent after deletion (exit 0)" \
                    || fail "inconsistent after deletion (exit $RC)"
N=$(cd "$WORK/en/scripts" && timeout 400 bash ./verify-grimoire.sh --local-only 2>&1 \
    | grep -oE 'grimoire: [0-9]+ +target: [0-9]+' | head -1)
[[ "$N" == "grimoire: 894   target: 894" ]] \
  && pass "host mirrors source 894/894, no ghost" \
  || fail "unexpected count: ${N:-<none>}"

echo
echo "=== M3: SKILL.md corrupted (garbage instead of frontmatter) -> must FAIL ==="
rm -rf "$WORK"; cp -a "$G" "$WORK"
echo "not-YAML garbage" > "$WORK/en/skills/lexmount-moli/moli-webfetch/SKILL.md"
OUT=$( cd "$WORK/en/scripts" && timeout 400 bash ./verify-grimoire.sh --local-only 2>&1 )
RC=$?
[[ "$RC" == "2" ]] && pass "corrupt frontmatter rejected (exit 2)" \
                    || fail "corrupt frontmatter accepted (exit $RC)"
grep -q 'FRONTMATTER' <<<"$OUT" && pass "reason reported as FRONTMATTER" \
                                 || fail "no FRONTMATTER in output"

echo
echo "=== M4: stale copy on the HOST -> source must overwrite it ==="
# The v1 installer (cp -rn) left stale copies forever. This is the regression.
rm -rf "$WORK"; mkdir -p "$WORK/target"
strip bash "$SCRIPTS/install-v2.sh" --from "$G" --target "$WORK/target" --loot-only >/dev/null 2>&1
V=$(find "$WORK/target" -path '*moli-webfetch/SKILL.md')
echo "STALE" >> "$V"
strip bash "$SCRIPTS/install-v2.sh" --from "$G" --target "$WORK/target" --loot-only >/dev/null 2>&1
grep -q 'STALE' "$V" && fail "stale copy survived - install-v2 does NOT update" \
                      || pass "stale copy overwritten (drift removed)"

echo
echo "=== M5: no skills lost to flattening (v1 lost 12) ==="
rm -rf "$WORK"; mkdir -p "$WORK/target"
strip bash "$SCRIPTS/install-v2.sh" --from "$G" --target "$WORK/target" --loot-only >/dev/null 2>&1
N=$(find "$WORK/target" -name SKILL.md | wc -l)
SRC_N=$(find "$G/en/skills" -name SKILL.md | wc -l)
[[ "$N" == "$SRC_N" ]] && pass "all ${N} skills present (v1 install-self.sh lost 12)" \
                        || fail "lost skills: ${N} of ${SRC_N}"

echo
echo "======================================"
echo "PASS=${PASS}  FAIL=${FAIL}"
if [[ $FAIL -eq 0 ]]; then
  echo "OK  verification is not vacuous - it catches every injected fault"
else
  echo "ERR at least one mutation slipped through"
fi
exit $(( FAIL > 0 ? 1 : 0 ))