#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/assert.sh
source "$ROOT/tests/assert.sh"

if [ "$(id -u)" -eq 0 ]; then
  printf 'This test must not run as root.\n' >&2
  exit 1
fi

tmp="$(mktemp -d)"
cleanup_test() {
  chmod -R u+w "$tmp" 2>/dev/null || true
  rm -rf "$tmp" || true
}
trap cleanup_test EXIT

make_program() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" << 'EOF'
#!/bin/sh
# /etc/resolv.conf
printf 'grok-ran\n'
exit 0
EOF
  chmod 700 "$dest"
}

# No program yet: explain how to install, and do not pretend grok ran.
empty="$tmp/empty-home"
mkdir -p "$empty"
dns="$tmp/dns"
printf 'nameserver 1.1.1.1\n' >"$dns"
set +e
out="$(env HOME="$empty" GROK_HOME="$empty" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'launcher should fail when nothing is installed\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "bash install.sh"
assert_not_contains "$out" "grok-ran"

# Missing DNS file: explain storage, and do not start grok.
home="$tmp/nodns-home"
mkdir -p "$home/.grok/versions"
make_program "$home/.grok/versions/1.2.3"
printf '1.2.3\n' >"$home/.grok/versions/.verified"
ro="$tmp/ro"
mkdir -p "$ro"
chmod 555 "$ro"
set +e
out="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$ro/.grokdns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'launcher should fail when the DNS file cannot be written\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "termux-setup-storage"
assert_not_contains "$out" "grok-ran"
left="$(find "$ro" -mindepth 1 -print || true)"
if [ -n "$left" ]; then
  printf 'temp files left in the unwritable folder:\n%s\n' "$left" >&2
  exit 1
fi

# Unpatched program: patch it, say so, keep a backup, then run it.
home="$tmp/patch-home"
mkdir -p "$home/.grok/versions"
make_program "$home/.grok/versions/1.2.3"
printf '1.2.3\n' >"$home/.grok/versions/.verified"
out="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" 2>&1)"
assert_contains "$out" "missing the DNS patch"
assert_contains "$out" "Applied the DNS patch"
assert_contains "$out" "grok-ran"
if grep -a -F -q -- '/etc/resolv.conf' "$home/.grok/versions/1.2.3"; then
  printf 'launcher left the program unpatched\n' >&2
  exit 1
fi
grep -a -F -q -- '/sdcard/.grokdns' "$home/.grok/versions/1.2.3"
grep -a -F -q -- '/etc/resolv.conf' "$home/.grok/versions/1.2.3.bak"
size_bin="$(wc -c <"$home/.grok/versions/1.2.3" | tr -d '[:space:]')"
size_bak="$(wc -c <"$home/.grok/versions/1.2.3.bak" | tr -d '[:space:]')"
assert_eq "$size_bin" "$size_bak"

out2="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" 2>&1)"
assert_contains "$out2" "grok-ran"
assert_not_contains "$out2" "Applied the DNS patch"
assert_not_contains "$out2" "missing the DNS patch"

# grok update drops a new unpatched download and repoints ~/.grok/bin/grok.
home="$tmp/update-home"
mkdir -p "$home/.grok/downloads" "$home/.grok/bin" "$home/.grok/versions"
make_program "$home/.grok/downloads/grok-2.0.0-linux-aarch64"
ln -s "$home/.grok/downloads/grok-2.0.0-linux-aarch64" "$home/.grok/bin/grok"
out="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" 2>&1)"
assert_contains "$out" "Picked up grok update 2.0.0."
assert_contains "$out" "missing the DNS patch"
assert_contains "$out" "grok-ran"
grep -a -F -q -- '/etc/resolv.conf' "$home/.grok/downloads/grok-2.0.0-linux-aarch64"
if grep -a -F -q -- '/etc/resolv.conf' "$home/.grok/versions/2.0.0"; then
  printf 'adopted update was not patched\n' >&2
  exit 1
fi
grep -a -F -q -- '/sdcard/.grokdns' "$home/.grok/versions/2.0.0"
verified="$(tr -d '[:space:]' <"$home/.grok/versions/.verified")"
assert_eq "$verified" "2.0.0"
