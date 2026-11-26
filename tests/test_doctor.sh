#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/assert.sh
source "$ROOT/tests/assert.sh"
# shellcheck source=common.sh
source "$ROOT/common.sh"

tmp="$(mktemp -d)"
cleanup_test() {
  chmod -R u+w "$tmp" 2>/dev/null || true
  rm -rf "$tmp" || true
}
trap cleanup_test EXIT

# Play Store and dead mirrors are recognized. A F-Droid mirror is not.
export GROK_PREFIX="$tmp/prefix"
mkdir -p "$GROK_PREFIX/etc/apt/sources.list.d"
export TERMUX_APK_RELEASE="GOOGLE_PLAYSTORE"
if ! termux_is_old; then
  printf 'Play Store Termux should be detected\n' >&2
  exit 1
fi
unset TERMUX_APK_RELEASE
printf 'deb https://dl.bintray.com/termux/termux-packages-24 stable main\n' >"$GROK_PREFIX/etc/apt/sources.list"
if ! termux_is_old; then
  printf 'bintray mirror should be detected\n' >&2
  exit 1
fi
printf 'deb https://packages.termux.dev/apt/termux-main stable main\n' >"$GROK_PREFIX/etc/apt/sources.list"
export TERMUX_APK_RELEASE="F_DROID"
if termux_is_old; then
  printf 'F-Droid Termux should not look old\n' >&2
  exit 1
fi

# Direct DNS query to a closed port fails. CI must not depend on the network.
set +e
python3 "$ROOT/grok-dns.py" query 127.0.0.1 api.x.ai >/dev/null 2>&1
qrc=$?
set -e
if [ "$qrc" -eq 0 ]; then
  printf 'query of 127.0.0.1 should fail\n' >&2
  exit 1
fi

# Doctor checklist, through every entry point.
home="$tmp/home"
mkdir -p "$home/.grok/versions" "$GROK_PREFIX/bin"
dns="$tmp/dns"
printf 'nameserver 127.0.0.1\n' >"$dns"
cat >"$home/.grok/versions/1.2.3" << 'EOF'
placeholder /sdcard/.grokdns
EOF
printf '1.2.3\n' >"$home/.grok/versions/.verified"

run_doctor() {
  env HOME="$home" GROK_HOME="$home" \
    PREFIX="$GROK_PREFIX" GROK_PREFIX="$GROK_PREFIX" \
    GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
    TERMUX_APK_RELEASE="F_DROID" \
    bash "$@"
}

expect_doctor() {
  local out rc
  set +e
  out="$(run_doctor "$@" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'doctor should fail on this machine\n%s\n' "$out" >&2
    exit 1
  fi
  assert_contains "$out" "grok doctor"
  assert_contains "$out" "Termux source"
  assert_contains "$out" "Storage:"
  assert_contains "$out" "DNS file:"
  assert_contains "$out" "api.x.ai"
  assert_contains "$out" "Binary:"
  assert_contains "$out" "Arch:"
  assert_contains "$out" "DNS patch is present"
}

expect_doctor "$ROOT/install.sh" --doctor
expect_doctor "$ROOT/launcher.sh" --doctor
expect_doctor "$ROOT/grok-doctor.sh"

if [ "$(id -u)" -eq 0 ]; then
  printf 'Skipping the unwritable storage check because this test is root.\n' >&2
else
  ro="$tmp/ro"
  mkdir -p "$ro"
  chmod 555 "$ro"
  GROK_DNS_FILE="$ro/.grokdns"
  if storage_writable; then
    printf 'storage_writable should fail without write permission\n' >&2
    exit 1
  fi
fi
