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

expect_ip() {
  local ip="$1" want="$2" got
  if valid_ip "$ip"; then
    got="yes"
  else
    got="no"
  fi
  assert_eq "$got" "$want"
}

expect_ip "1.1.1.1" "yes"
expect_ip "8.8.8.8" "yes"
expect_ip "10.0.0.1" "yes"
expect_ip "2001:4860:4860::8888" "yes"
expect_ip "999.1.1.1" "no"
expect_ip "1.2.3" "no"
expect_ip "0.0.0.0" "no"
expect_ip "127.0.0.1" "no"
expect_ip "" "no"
expect_ip "08.8.8.8" "no"
expect_ip "not-an-ip" "no"

unset GROK_DNS
export GROK_MOCK_GETPROP=1
export GROK_PROP_DNS1=""
export GROK_PROP_DNS2=""
export GROK_DNS_FILE="$tmp/default-dns"
write_dns_file "$GROK_DNS_FILE"
grep -F -q -- 'nameserver 1.1.1.1' "$GROK_DNS_FILE"
grep -F -q -- 'nameserver 8.8.8.8' "$GROK_DNS_FILE"

export GROK_PROP_DNS1="10.1.2.3"
export GROK_PROP_DNS2="10.1.2.4"
export GROK_DNS_FILE="$tmp/phone-dns"
write_dns_file "$GROK_DNS_FILE"
grep -F -q -- 'nameserver 10.1.2.3' "$GROK_DNS_FILE"
grep -F -q -- 'nameserver 10.1.2.4' "$GROK_DNS_FILE"
if grep -F -q -- '1.1.1.1' "$GROK_DNS_FILE"; then
  printf 'public DNS overwrote the phone DNS\n' >&2
  exit 1
fi

# The same phone server twice is written once.
export GROK_PROP_DNS2="10.1.2.3"
export GROK_DNS_FILE="$tmp/dup-dns"
write_dns_file "$GROK_DNS_FILE"
count="$(grep -c -F -- 'nameserver 10.1.2.3' "$GROK_DNS_FILE" | tr -d '[:space:]')"
assert_eq "$count" "1"

# A valid file is kept when GROK_DNS is not set.
unset GROK_DNS
export GROK_DNS_FILE="$tmp/kept-dns"
printf 'nameserver 9.9.9.9\n' >"$GROK_DNS_FILE"
ensure_dns_file
body="$(tr -d '\r' <"$GROK_DNS_FILE")"
assert_eq "$body" "nameserver 9.9.9.9"

# GROK_DNS replaces that file.
export GROK_DNS="1.0.0.1 8.8.4.4"
ensure_dns_file
grep -F -q -- 'nameserver 1.0.0.1' "$GROK_DNS_FILE"
grep -F -q -- 'nameserver 8.8.4.4' "$GROK_DNS_FILE"
if grep -F -q -- '9.9.9.9' "$GROK_DNS_FILE"; then
  printf 'old nameserver was kept\n' >&2
  exit 1
fi

# A bad GROK_DNS value fails before a new file is created.
export GROK_DNS="not-an-ip"
export GROK_DNS_FILE="$tmp/missing-dir/dns"
set +e
out="$(write_dns_file "$GROK_DNS_FILE" 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'bad GROK_DNS should fail\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "cannot use"
[ ! -e "$GROK_DNS_FILE" ]
