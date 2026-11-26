#!/usr/bin/env bash
# Official ~/.grok/bin/grok must not hide the Termux launcher.
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

dns="$tmp/dns"
printf 'nameserver 9.9.9.9\n' >"$dns"

write_fake_program() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" << 'EOF'
#!/bin/sh
# /etc/resolv.conf
if [ "${1:-}" = "--version" ]; then
  printf 'grok test\n'
  exit 0
fi
printf 'grok-ran\n'
exit 0
EOF
  chmod 700 "$dest"
}

install_mocks() {
  local mock="$1"
  mkdir -p "$mock"
  cat >"$mock/curl" << 'MOCK'
#!/bin/bash
set -euo pipefail
out=""
prev=""
url=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    out="$arg"
  fi
  case "$arg" in
    http*) url="$arg" ;;
  esac
  prev="$arg"
done
case "$url" in
  */alpha)
    printf '1.0.94\n'
    exit 0
    ;;
  */stable)
    printf '1.0.92\n'
    exit 0
    ;;
  */enterprise)
    printf '1.0.90\n'
    exit 0
    ;;
esac
if [ -z "$out" ]; then
  printf 'mock curl: missing -o for %s\n' "$url" >&2
  exit 2
fi
if [ -n "${COUNTFILE:-}" ]; then
  printf '%s\n' "$url" >>"$COUNTFILE"
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
}

run_install() {
  local -a channel_env=()
  if [ -n "${GROK_CHANNEL:-}" ]; then
    channel_env=("GROK_CHANNEL=$GROK_CHANNEL")
  fi
  # shellcheck disable=SC2068
  env -u GROK_DNS -u GROK_CHANNEL \
    HOME="$HOME" \
    GROK_HOME="$GROK_HOME" \
    PREFIX="$PREFIX" \
    GROK_PREFIX="$GROK_PREFIX" \
    GROK_DNS_FILE="$dns" \
    GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
    GROK_SKIP_ARCH_CHECK=1 \
    GROK_SKIP_PKG=1 \
    GROK_MOCK_GETPROP=1 \
    GROK_PROP_DNS1="" \
    GROK_PROP_DNS2="" \
    PATH="$PATH" \
    COUNTFILE="${COUNTFILE:-}" \
    TERMUX_APK_RELEASE="F_DROID" \
    ${channel_env[@]+"${channel_env[@]}"} \
    bash "$ROOT/install.sh" "$@"
}

# --- bad channel fails before any install claim ---
set +e
out="$(env HOME="$tmp/bad-channel" GROK_CHANNEL=beta bash "$ROOT/install.sh" 2>&1)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf 'bad GROK_CHANNEL should fail\n%s\n' "$out" >&2
  exit 1
fi
assert_contains "$out" "stable, alpha, or enterprise"
assert_not_contains "$out" "Installed grok"

# --- install hides an official grok that is earlier on PATH ---
home="$tmp/shadow-home"
prefix="$tmp/shadow-prefix"
mock="$tmp/shadow-mock"
outside="$tmp/outside-bin"
mkdir -p "$home/.grok/bin" "$home/.local/bin" "$prefix/bin" "$outside"
install_mocks "$mock"
printf '#!/bin/sh\nprintf "RAW\\n"\nexit 0\n' >"$home/.grok/bin/raw-grok"
chmod 700 "$home/.grok/bin/raw-grok"
ln -s raw-grok "$home/.grok/bin/grok"
ln -s "$home/.grok/bin/raw-grok" "$home/.local/bin/grok"
printf '#!/bin/sh\nprintf "OUTSIDE\\n"\nexit 0\n' >"$outside/grok"
chmod 700 "$outside/grok"
cat >"$home/.bashrc" << 'EOF'
echo keep-me
# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
# <<< grok installer <<<
export PATH="$PATH:$HOME/.grok/bin"
EOF
cp -f "$home/.bashrc" "$home/.profile"
cp -f "$home/.bashrc" "$home/.zshrc"
cp -f "$home/.bashrc" "$tmp/bashrc-original"
export HOME="$home" GROK_HOME="$home" PREFIX="$prefix" GROK_PREFIX="$prefix"
export PATH="$outside:$home/.local/bin:$home/.grok/bin:$prefix/bin:$mock:$PATH"
unset GROK_CHANNEL || true

out="$(run_install 1.2.3 2>&1)"
assert_contains "$out" "Installed grok 1.2.3."
assert_contains "$out" "Release channel: stable."
assert_contains "$out" "hash -r"
assert_contains "$out" "Commented the official grok PATH line"
assert_not_contains "$out" "ERROR:"
# The copy outside the home folder is not ours to move.
[ -x "$outside/grok" ]
grep -F -q 'OUTSIDE' "$outside/grok"

[ -L "$home/.grok/bin/grok" ]
[ -L "$home/.local/bin/grok" ]
launcher_real="$(readlink -f "$prefix/bin/grok")"
assert_eq "$(readlink -f "$home/.grok/bin/grok")" "$launcher_real"
assert_eq "$(readlink -f "$home/.local/bin/grok")" "$launcher_real"
grep -F -q 'RAW' "$home/.grok/bin/grok.viejo"
[ -f "$home/.local/bin/grok.viejo" ] || [ -L "$home/.local/bin/grok.viejo" ]
dollar='$'
grep -F -q 'keep-me' "$home/.bashrc"
grep -F -q "# grok-termux-native: export PATH=\"${dollar}HOME/.grok/bin:${dollar}PATH\"" "$home/.bashrc"
grep -F -q "source \"${dollar}HOME/.grok/completions/bash/grok.bash\"" "$home/.bashrc"
grep -F -q "export PATH=\"${dollar}PATH:${dollar}HOME/.grok/bin\"" "$home/.bashrc"
active=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    '#'*) continue ;;
  esac
  case "$line" in
    *".grok/bin:${dollar}PATH"*) active=1 ;;
  esac
done <"$home/.bashrc"
if [ "$active" -ne 0 ]; then
  printf 'official PATH line is still active in bashrc\n' >&2
  exit 1
fi
cmp -s "$tmp/bashrc-original" "$home/.bashrc.grok-native-bak"
cmp -s "$tmp/bashrc-original" "$home/.profile.grok-native-bak"
cmp -s "$tmp/bashrc-original" "$home/.zshrc.grok-native-bak"
grep -F -q 'channel = "stable"' "$home/.grok/config.toml"
assert_eq "$(tr -d '[:space:]' <"$home/.grok/versions/.channel")" "stable"

# Second install does not eat the backup or comment the line twice.
cp -f "$home/.bashrc" "$tmp/bashrc-once"
cp -f "$home/.grok/bin/grok.viejo" "$tmp/viejo-once"
out2="$(run_install 1.2.3 2>&1)"
assert_contains "$out2" "Installed grok 1.2.3."
assert_not_contains "$out2" "ERROR:"
cmp -s "$tmp/bashrc-once" "$home/.bashrc"
cmp -s "$tmp/bashrc-original" "$home/.bashrc.grok-native-bak"
cmp -s "$tmp/viejo-once" "$home/.grok/bin/grok.viejo"
count="$(grep -c 'grok-termux-native:' "$home/.bashrc" | tr -d '[:space:]')"
assert_eq "$count" "1"

# The shell still has ~/.grok/bin first, but that file is our launcher.
hash -r
ran="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  PATH="$home/.grok/bin:$prefix/bin:$PATH" \
  timeout -s KILL 10 bash "$home/.grok/bin/grok" 2>&1)"
assert_contains "$ran" "grok-ran"
assert_not_contains "$ran" "RAW"
runs="$(grep -c 'grok-ran' <<< "$ran" | tr -d '[:space:]')"
assert_eq "$runs" "1"

# Doctor fails while a foreign grok is first, with the manual fix command.
doc="$(env HOME="$home" GROK_HOME="$home" \
  PREFIX="$prefix" GROK_PREFIX="$prefix" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  TERMUX_APK_RELEASE="F_DROID" \
  PATH="$outside:$prefix/bin:/usr/bin:/bin" \
  bash "$ROOT/grok-doctor.sh" 2>&1 || true)"
assert_contains "$doc" "mv ~/.grok/bin/grok ~/.grok/bin/grok.viejo; hash -r"
assert_contains "$doc" "not the Termux launcher"

doc_ok="$(env HOME="$home" GROK_HOME="$home" \
  PREFIX="$prefix" GROK_PREFIX="$prefix" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  TERMUX_APK_RELEASE="F_DROID" \
  PATH="$home/.grok/bin:$prefix/bin:/usr/bin:/bin" \
  bash "$ROOT/grok-doctor.sh" 2>&1 || true)"
assert_contains "$doc_ok" "Termux launcher"
assert_not_contains "$doc_ok" "not the Termux launcher"

# Uninstall puts the backups back.
env HOME="$home" GROK_HOME="$home" \
  PREFIX="$prefix" GROK_PREFIX="$prefix" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/uninstall.sh" >/dev/null
cmp -s "$tmp/bashrc-original" "$home/.bashrc"
cmp -s "$tmp/bashrc-original" "$home/.profile"
cmp -s "$tmp/bashrc-original" "$home/.zshrc"
grep -F -q 'RAW' "$home/.grok/bin/grok"
if [ -e "$home/.grok/bin/grok.viejo" ]; then
  printf 'grok.viejo should have been restored onto grok\n' >&2
  exit 1
fi
if [ -e "$prefix/bin/grok" ]; then
  printf 'prefix grok command should be gone\n' >&2
  exit 1
fi
printf 'nameserver 9.9.9.9\n' >"$dns"

# --- GROK_CHANNEL=alpha selects the alpha pointer and is what update uses ---
home="$tmp/alpha-home"
prefix="$tmp/alpha-prefix"
mock="$tmp/alpha-mock"
count="$tmp/alpha-urls"
mkdir -p "$home" "$prefix"
install_mocks "$mock"
: >"$count"
export HOME="$home" GROK_HOME="$home" PREFIX="$prefix" GROK_PREFIX="$prefix"
export PATH="$mock:/usr/bin:/bin"
export COUNTFILE="$count"
export GROK_CHANNEL="alpha"
# Keep a setting the channel writer must not delete.
mkdir -p "$home/.grok"
cat >"$home/.grok/config.toml" << 'EOF'
[cli]
installer = "internal"
theme = "dark"

[other]
x = 1
EOF
out="$(run_install 2>&1)"
assert_contains "$out" "Installed grok 1.0.94."
assert_contains "$out" "Release channel: alpha."
assert_eq "$(tr -d '[:space:]' <"$home/.grok/versions/.channel")" "alpha"
grep -F -q 'channel = "alpha"' "$home/.grok/config.toml"
grep -F -q 'installer = "internal"' "$home/.grok/config.toml"
grep -F -q 'theme = "dark"' "$home/.grok/config.toml"
grep -F -q 'x = 1' "$home/.grok/config.toml"
if grep -F -q '/stable' "$count"; then
  printf 'alpha install looked up stable\n%s\n' "$(cat "$count")" >&2
  exit 1
fi
grep -F -q 'grok-1.0.94-linux-aarch64' "$count"

# A saved alpha channel is what `grok update` writes before the program runs.
# --stable on the command line wins over that saved channel.
mkdir -p "$home/.grok/bin" "$home/.grok/downloads" "$home/.grok/versions"
printf '1.0.94\n' >"$home/.grok/versions/.verified"
# The download path is built in two pieces so the DNS patch of THIS file
# does not rewrite the program it is about to write.
cat >"$home/.grok/versions/1.0.94" << 'EOF'
#!/bin/sh
# /etc/resolv.conf
cfg="${GROK_HOME:-$HOME}/.grok/config.toml"
if [ "${1:-}" = "update" ]; then
  grep -F 'channel = ' "$cfg" || true
  dest="${GROK_HOME:-$HOME}/.grok/downloads/grok-2.0.0-linux-aarch64"
  mkdir -p "$(dirname "$dest")" "${GROK_HOME:-$HOME}/.grok/bin"
  native="/etc/resolv"
  native="${native}.conf"
  printf '%s\n' '#!/bin/sh' "# ${native}" 'printf "updated-ran\n"' 'exit 0' >"$dest"
  chmod 700 "$dest"
  ln -sfn "../downloads/grok-2.0.0-linux-aarch64" "${GROK_HOME:-$HOME}/.grok/bin/grok"
  exit 7
fi
printf 'grok-ran\n'
exit 0
EOF
chmod 700 "$home/.grok/versions/1.0.94"
# Drop the channel line so the launcher must restore it from .channel.
cat >"$home/.grok/config.toml" << 'EOF'
[cli]
installer = "internal"
EOF
unset GROK_CHANNEL || true
set +e
upd="$(env HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  PATH="$prefix/bin:/usr/bin:/bin" \
  bash "$ROOT/launcher.sh" update 2>&1)"
rc=$?
set -e
if [ "$rc" -ne 7 ]; then
  printf 'update should return the program exit code 7, got %s\n%s\n' "$rc" "$upd" >&2
  exit 1
fi
assert_contains "$upd" 'channel = "alpha"'
assert_contains "$upd" "Picked up grok update 2.0.0."
assert_contains "$upd" "Applied the DNS patch"
assert_contains "$upd" "hash -r"
grep -F -q '/sdcard/.grokdns' "$home/.grok/versions/2.0.0"
if grep -a -F -q '/etc/resolv.conf' "$home/.grok/versions/2.0.0"; then
  printf 'updated program was not patched\n' >&2
  exit 1
fi
# The download itself stays unpatched; the launcher runs the versions copy.
grep -a -F -q '/etc/resolv.conf' "$home/.grok/downloads/grok-2.0.0-linux-aarch64"
assert_eq "$(readlink -f "$home/.grok/bin/grok")" "$(readlink -f "$prefix/bin/grok")"
grep -F -q 'channel = "alpha"' "$home/.grok/config.toml"

# Relative official symlink, the layout install.sh and grok update write.
home="$tmp/rel-home"
mkdir -p "$home/.grok/downloads" "$home/.grok/bin" "$home/.grok/versions"
write_fake_program "$home/.grok/downloads/grok-3.1.0-linux-aarch64"
ln -s "../downloads/grok-3.1.0-linux-aarch64" "$home/.grok/bin/grok"
rel="$(env -u PREFIX -u GROK_PREFIX \
  HOME="$home" GROK_HOME="$home" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" 2>&1)"
assert_contains "$rel" "Picked up grok update 3.1.0."
assert_contains "$rel" "grok-ran"
grep -F -q '/sdcard/.grokdns' "$home/.grok/versions/3.1.0"
assert_eq "$(readlink -f "$home/.grok/bin/grok")" "$(readlink -f "$ROOT/launcher.sh")"

# --stable overrides a saved alpha channel for this update.
home="$tmp/flag-home"
mkdir -p "$home/.grok/versions"
printf 'alpha\n' >"$home/.grok/versions/.channel"
printf '1.0.94\n' >"$home/.grok/versions/.verified"
cat >"$home/.grok/versions/1.0.94" << 'EOF'
#!/bin/sh
# /etc/resolv.conf
cfg="${GROK_HOME:-$HOME}/.grok/config.toml"
grep -F 'channel = ' "$cfg" || true
exit 0
EOF
chmod 700 "$home/.grok/versions/1.0.94"
flag="$(env HOME="$home" GROK_HOME="$home" GROK_CHANNEL="alpha" \
  GROK_DNS_FILE="$dns" GROK_SYSTEM_RESOLV="$tmp/no-such-resolv" \
  bash "$ROOT/launcher.sh" update --stable 2>&1)"
assert_contains "$flag" 'channel = "stable"'
assert_eq "$(tr -d '[:space:]' <"$home/.grok/versions/.channel")" "stable"
