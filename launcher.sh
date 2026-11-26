#!/data/data/com.termux/files/usr/bin/bash
# grok — native Termux launcher (xAI Grok Build, static musl binary). No proot.
#
# Before grok starts, this checks the DNS file and the 16-byte path inside
# the program. `grok update` downloads a fresh program that still says
# /etc/resolv.conf, so the patch is applied again and a backup is kept.
set -euo pipefail

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "main" ]; then
  printf 'Could not find the launcher folder.\n' >&2
  exit 1
fi
_self="${BASH_SOURCE[0]}"
_dir=""
_link=""
while [ -L "$_self" ]; do
  _dir="$(cd "$(dirname "$_self")" && pwd)" || {
    printf 'Could not open the folder of %s\n' "$_self" >&2
    exit 1
  }
  _link="$(readlink "$_self")" || {
    printf 'Could not read the shortcut %s\n' "$_self" >&2
    exit 1
  }
  case "$_link" in
    /*) _self="$_link" ;;
    *) _self="$_dir/$_link" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)" || {
  printf 'Could not open the folder of %s\n' "$_self" >&2
  exit 1
}
unset _self _dir _link

if [ ! -f "$SCRIPT_DIR/common.sh" ]; then
  printf 'Missing %s/common.sh. Run: bash install.sh\n' "$SCRIPT_DIR" >&2
  exit 1
fi
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
GROK_SCRIPT_DIR="$SCRIPT_DIR"

if [ "${1:-}" = "--doctor" ] || [ "${1:-}" = "doctor" ]; then
  doctor || exit 1
  exit 0
fi

# grok's own updater points ~/.grok/bin/grok at a new download and does not
# update the versions folder this launcher runs. Copy that download across.
adopt_self_update() {
  local home bin upd base uver dest verified current
  home="$(grok_home)"
  bin="$home/.grok/bin/grok"
  if [ ! -e "$bin" ] && [ ! -L "$bin" ]; then
    return 0
  fi
  upd=""
  if [ -L "$bin" ] || [ -e "$bin" ]; then
    # A missing updater symlink is normal before the first `grok update`.
    upd="$(readlink -f "$bin" 2>/dev/null || true)"
  fi
  [ -n "$upd" ] || return 0
  base="$(basename "$upd")"
  case "$base" in
    grok-*-linux-aarch64) ;;
    *) return 0 ;;
  esac
  uver="${base#grok-}"
  uver="${uver%-linux-aarch64}"
  if [[ ! "$uver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  fi
  if [ ! -f "$upd" ]; then
    return 0
  fi
  mkdir -p -- "$(grok_versions_dir)" || die "Could not create $(grok_versions_dir)."
  dest="$(grok_versions_dir)/$uver"
  verified="$(grok_versions_dir)/.verified"
  if [ ! -f "$dest" ]; then
    cp -f -- "$upd" "$dest" || die "Could not copy the updated grok program to $dest."
    chmod 700 "$dest" || die "Could not set permissions on $dest."
    printf '%s\n' "$uver" >"$verified" || die "Could not write $verified."
    say "Picked up grok update $uver."
    return 0
  fi
  current=""
  if [ -f "$verified" ]; then
    current="$(tr -d '[:space:]' < "$verified")"
  fi
  if [ "$current" != "$uver" ]; then
    printf '%s\n' "$uver" >"$verified" || die "Could not write $verified."
    say "Switched to grok $uver."
  fi
}

adopt_self_update

bin=""
if ! bin="$(current_grok_bin)"; then
  die "No grok program is installed yet. Run: bash install.sh"
fi

if system_resolv_ok; then
  MODE="native"
else
  MODE="sdcard"
  if ! dns_file_valid "$(dns_file_path)"; then
    ensure_dns_file
  fi
  if ! dns_file_valid "$(dns_file_path)"; then
    die "The DNS file $(dns_file_path) has no nameserver. Run termux-setup-storage, then run: bash install.sh"
  fi
  if [ "$(dns_file_path)" != "$RESOLV_SDCARD" ]; then
    say "WARNING: DNS file is $(dns_file_path). The grok program only reads $RESOLV_SDCARD. Leave GROK_DNS_FILE unset on a phone."
  fi
fi

if [ ! -f "$SCRIPT_DIR/grok-dns.py" ]; then
  die "Missing $SCRIPT_DIR/grok-dns.py. Run: bash install.sh"
fi

if [ "$MODE" = "sdcard" ] && file_contains "$bin" "$RESOLV_NATIVE"; then
  say "The grok program is missing the DNS patch. This happens after 'grok update' replaces the program."
fi

patch_grok_binary "$bin" "$MODE" "$SCRIPT_DIR/grok-dns.py"

exec "$bin" "$@" || die "Could not start $bin."
