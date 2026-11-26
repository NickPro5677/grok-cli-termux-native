#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/assert.sh
source "$ROOT/tests/assert.sh"
# shellcheck source=common.sh
source "$ROOT/common.sh"

tmp="$(mktemp -d)"
cleanup_test() {
  rm -rf "$tmp" || true
}
trap cleanup_test EXIT

assert_eq "${#RESOLV_NATIVE}" "16"
assert_eq "${#RESOLV_SDCARD}" "16"

bin="$tmp/grok-dummy"
orig="$tmp/original"
printf '>>>/etc/resolv.conf<<<>>>/etc/resolv.conf<<<' >"$bin"
cp -f -- "$bin" "$orig"
size_before="$(wc -c < "$bin" | tr -d '[:space:]')"

out="$(patch_grok_binary "$bin" sdcard "$ROOT/grok-dns.py" 2>&1)"
assert_contains "$out" "Applied the DNS patch"
assert_contains "$out" "Saved a backup here:"
size_after="$(wc -c < "$bin" | tr -d '[:space:]')"
assert_eq "$size_before" "$size_after"
if grep -a -F -q -- '/etc/resolv.conf' "$bin"; then
  printf 'original string still present\n' >&2
  exit 1
fi
count="$(grep -a -o -F -- '/sdcard/.grokdns' "$bin" | wc -l | tr -d '[:space:]')"
assert_eq "$count" "2"
grep -a -F -q -- '>>>/sdcard/.grokdns<<<>>>/sdcard/.grokdns<<<' "$bin"
cmp -s "$orig" "$bin.bak"

# A second run changes nothing and does not replace the backup.
out2="$(patch_grok_binary "$bin" sdcard "$ROOT/grok-dns.py" 2>&1)"
assert_not_contains "$out2" "Applied the DNS patch"
cmp -s "$orig" "$bin.bak"
count="$(grep -a -o -F -- '/sdcard/.grokdns' "$bin" | wc -l | tr -d '[:space:]')"
assert_eq "$count" "2"

# Switching back to the system path is the same 16-byte swap.
out3="$(patch_grok_binary "$bin" native "$ROOT/grok-dns.py" 2>&1)"
assert_contains "$out3" "Applied the DNS patch"
assert_contains "$out3" "/etc/resolv.conf"
if grep -a -F -q -- '/sdcard/.grokdns' "$bin"; then
  printf 'sdcard string still present after native swap\n' >&2
  exit 1
fi
cmp -s "$orig" "$bin"
grep -a -F -q -- '/sdcard/.grokdns' "$bin.bak"

# A file with neither path is rejected and not backed up.
plain="$tmp/plain"
printf 'hello\n' >"$plain"
set +e
out4="$(patch_grok_binary "$plain" sdcard "$ROOT/grok-dns.py" 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'patch should have failed\n%s\n' "$out4" >&2
  exit 1
fi
assert_contains "$out4" "does not contain"
[ ! -e "$plain.bak" ]
grep -F -q -- 'hello' "$plain"

# Both paths in one file: only the requested path remains.
both="$tmp/both"
printf 'X/etc/resolv.confY/sdcard/.grokdnsZ' >"$both"
patch_grok_binary "$both" sdcard "$ROOT/grok-dns.py" >/dev/null
if grep -a -F -q -- '/etc/resolv.conf' "$both"; then
  printf 'native path left in mixed file\n' >&2
  exit 1
fi
count="$(grep -a -o -F -- '/sdcard/.grokdns' "$both" | wc -l | tr -d '[:space:]')"
assert_eq "$count" "2"
