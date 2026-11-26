#!/usr/bin/env bash
# Runs install.sh with fake paths. Nothing here touches a real phone.
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

run_install() {
  # Arguments are extra env assignments, then the install.sh args live in INSTALL_ARGS.
  env -u TERMUX_APK_RELEASE -u GROK_DNS \
    HOME="$HOME" \
    GROK_HOME="$GROK_HOME" \
    PREFIX="$PREFIX" \
    GROK_PREFIX="$GROK_PREFIX" \
    GROK_DNS_FILE="$GROK_DNS_FILE" \
    GROK_SYSTEM_RESOLV="$GROK_SYSTEM_RESOLV" \
    GROK_SKIP_ARCH_CHECK=1 \
    GROK_SKIP_PKG=1 \
    GROK_MOCK_GETPROP=1 \
    GROK_PROP_DNS1="${GROK_PROP_DNS1:-}" \
    GROK_PROP_DNS2="${GROK_PROP_DNS2:-}" \
    PATH="$PATH" \
    COUNTFILE="${COUNTFILE:-}" \
    TERMUX_APK_RELEASE="${TERMUX_APK_RELEASE:-}" \
    bash "$ROOT/install.sh" "$@"
}

# --- help does not claim the install succeeded ---
help_out="$(bash "$ROOT/install.sh" --help 2>&1)"
assert_contains "$help_out" "termux-setup-storage"
assert_not_contains "$help_out" "Installed grok"

# --- DNS file cannot be written ---
home="$tmp/unwritable-home"
prefix="$tmp/unwritable-prefix"
ro="$tmp/ro"
mkdir -p "$home" "$prefix" "$ro"
chmod 555 "$ro"
export HOME="$home" GROK_HOME="$home" PREFIX="$prefix" GROK_PREFIX="$prefix"
export GROK_DNS_FILE="$ro/.grokdns"
export GROK_SYSTEM_RESOLV="$tmp/no-such-resolv"
export GROK_PROP_DNS1="" GROK_PROP_DNS2=""
unset TERMUX_APK_RELEASE || true
set +e
out="$(run_install 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'unwritable DNS should fail\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "termux-setup-storage"
assert_not_contains "$out" "Installed grok"
left="$(find "$ro" -mindepth 1 -print || true)"
if [ -n "$left" ]; then
  printf 'temp files left in the unwritable folder:\n%s\n' "$left" >&2
  exit 1
fi

# --- bad GROK_DNS does not clobber a good file and does not say Installed ---
home="$tmp/bad-dns-home"
prefix="$tmp/bad-dns-prefix"
mkdir -p "$home" "$prefix"
export HOME="$home" GROK_HOME="$home" PREFIX="$prefix" GROK_PREFIX="$prefix"
export GROK_DNS_FILE="$tmp/bad-dns"
export GROK_SYSTEM_RESOLV="$tmp/no-such-resolv"
printf 'nameserver 9.9.9.9\n' >"$GROK_DNS_FILE"
set +e
out="$(env GROK_DNS="not-an-ip" \
  HOME="$HOME" GROK_HOME="$GROK_HOME" PREFIX="$PREFIX" GROK_PREFIX="$GROK_PREFIX" \
  GROK_DNS_FILE="$GROK_DNS_FILE" GROK_SYSTEM_RESOLV="$GROK_SYSTEM_RESOLV" \
  GROK_SKIP_ARCH_CHECK=1 GROK_SKIP_PKG=1 GROK_MOCK_GETPROP=1 \
  bash "$ROOT/install.sh" 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'bad GROK_DNS should fail\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "cannot use"
assert_not_contains "$out" "Installed grok"
body="$(tr -d '\r' <"$GROK_DNS_FILE")"
assert_eq "$body" "nameserver 9.9.9.9"
if find "$tmp" -name '.grokdns.*' | grep -q .; then
  printf 'DNS temp file was left behind\n' >&2
  exit 1
fi

# --- download failure removes the temp file and does not say Installed ---
home="$tmp/dl-home"
prefix="$tmp/dl-prefix"
mock="$tmp/dl-mock"
mkdir -p "$home" "$prefix" "$mock"
export HOME="$home" GROK_HOME="$home" PREFIX="$prefix" GROK_PREFIX="$prefix"
export GROK_DNS_FILE="$tmp/dl-dns"
export GROK_SYSTEM_RESOLV="$tmp/no-such-resolv"
printf 'nameserver 9.9.9.9\n' >"$GROK_DNS_FILE"
export TERMUX_APK_RELEASE="GOOGLE_PLAYSTORE"
export PATH="$mock:$PATH"
cat >"$mock/curl" << 'MOCK'
#!/bin/bash
set -euo pipefail
out=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    out="$arg"
  fi
  prev="$arg"
done
if [ -n "$out" ]; then
  printf 'partial\n' >"$out"
fi
exit 1
MOCK
chmod +x "$mock/curl"
set +e
out="$(run_install 1.2.3 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'download failure should stop the install\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "Download failed"
assert_contains "$out" "termux-change-repo"
assert_contains "$out" "pkg upgrade"
assert_not_contains "$out" "Installed grok"
if [ -e "$home/.grok/versions/1.2.3.tmp" ] || [ -e "$home/.grok/versions/1.2.3" ]; then
  printf 'download temp or final binary was left behind\n' >&2
  find "$home/.grok" -print >&2 || true
  exit 1
fi

# --- successful install, then a second run that does not download again ---
home="$tmp/ok-home"
prefix="$tmp/ok-prefix"
mock="$tmp/ok-mock"
count="$tmp/curl.count"
mkdir -p "$home" "$prefix" "$mock"
: >"$count"
export HOME="$home" GROK_HOME="$home" PREFIX="$prefix" GROK_PREFIX="$prefix"
export GROK_DNS_FILE="$tmp/ok-dns"
export GROK_SYSTEM_RESOLV="$tmp/no-such-resolv"
export TERMUX_APK_RELEASE="F_DROID"
export COUNTFILE="$count"
export PATH="$mock:$PATH"
printf 'nameserver 9.9.9.9\n' >"$GROK_DNS_FILE"
cat >"$mock/curl" << 'MOCK'
#!/bin/bash
set -euo pipefail
out=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    out="$arg"
  fi
  prev="$arg"
done
if [ -n "${COUNTFILE:-}" ]; then
  printf '%s\n' "$*" >>"$COUNTFILE"
fi
if [ -z "$out" ]; then
  printf 'mock curl: missing -o\n' >&2
  exit 2
fi
cat >"$out" << 'EOF'
#!/bin/sh
# /etc/resolv.conf
if [ "${1:-}" = "--version" ]; then
  printf 'grok test\n'
  exit 0
fi
printf 'grok-ran\n'
exit 0
EOF
exit 0
MOCK
cat >"$mock/file" << 'MOCK'
#!/bin/bash
printf 'ELF statically linked\n'
exit 0
MOCK
chmod +x "$mock/curl" "$mock/file"

out="$(run_install 1.2.3 2>&1)"
assert_contains "$out" "Installed grok 1.2.3."
assert_contains "$out" "Applied the DNS patch"
assert_not_contains "$out" "ERROR:"
if grep -a -F -q -- '/etc/resolv.conf' "$home/.grok/versions/1.2.3"; then
  printf 'installed program still has /etc/resolv.conf\n' >&2
  exit 1
fi
grep -a -F -q -- '/sdcard/.grokdns' "$home/.grok/versions/1.2.3"
grep -a -F -q -- '/etc/resolv.conf' "$home/.grok/versions/1.2.3.bak"
body="$(tr -d '\r' <"$GROK_DNS_FILE")"
assert_eq "$body" "nameserver 9.9.9.9"
[ -L "$prefix/bin/grok" ]
[ -L "$prefix/bin/grok-doctor" ]
[ -f "$home/agents/grok/common.sh" ]
count1="$(wc -l <"$count" | tr -d '[:space:]')"
assert_eq "$count1" "1"

out2="$(run_install 1.2.3 2>&1)"
assert_contains "$out2" "Skipping the download."
assert_contains "$out2" "Installed grok 1.2.3."
assert_not_contains "$out2" "Applied the DNS patch"
count2="$(wc -l <"$count" | tr -d '[:space:]')"
assert_eq "$count2" "1"
body="$(tr -d '\r' <"$GROK_DNS_FILE")"
assert_eq "$body" "nameserver 9.9.9.9"

launch="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$GROK_DNS_FILE" GROK_SYSTEM_RESOLV="$GROK_SYSTEM_RESOLV" \
  bash "$prefix/bin/grok" 2>&1)"
assert_contains "$launch" "grok-ran"
assert_not_contains "$launch" "missing the DNS patch"
