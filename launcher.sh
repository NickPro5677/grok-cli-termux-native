#!/data/data/com.termux/files/usr/bin/bash
# grok — native Termux launcher (xAI Grok Build, static musl binary). No proot.
#
# Before grok starts, this checks the DNS file and the 16-byte path inside
# the program. `grok update` downloads a fresh program that still says
# /etc/resolv.conf, so the patch is applied again and a backup is kept.
# The official installer also puts an unpatched grok first on PATH. This
# launcher puts that shortcut back on our script after an update.
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

# grok update rewrites ~/.grok/bin/grok. Copy that download into versions/
# before this launcher replaces the shortcut with itself.
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

refuse_launcher_binary() {
  local real self
  real="$(readlink -f -- "$1" 2>/dev/null || true)"
  self="$(readlink -f -- "$SCRIPT_DIR/launcher.sh" 2>/dev/null || true)"
  if [ -n "$real" ] && [ -n "$self" ] && [ "$real" = "$self" ]; then
    die "Refusing to start the launcher as if it were the grok program. Run: bash install.sh"
  fi
}

refuse_launcher_binary "$bin"

patch_grok_binary "$bin" "$MODE" "$SCRIPT_DIR/grok-dns.py"

# `grok update` swaps ~/.grok/bin/grok and may restart that path. Run it as a
# child, then put our launcher back and patch the new program. A restart that
# lands here again must exec the real program, or it would loop.
if [ "${GROK_UPDATE_WRAPPED:-}" = "1" ]; then
  # The updater restarted this launcher. Point ~/.grok/bin/grok at the real
  # program before exec, or the next restart would call this script again.
  prepare_link_for_update "$bin" || true
  exec "$bin" "$@" || die "Could not start $bin."
fi

if [ "${1:-}" = "update" ]; then
  channel="$(channel_for_invocation "$(read_grok_channel)" "$@")"
  if ! save_grok_channel "$channel"; then
    say "WARNING: could not save release channel $channel."
  fi
  if ! prepare_link_for_update "$bin"; then
    say "WARNING: could not prepare ~/.grok/bin/grok for the update."
  fi
  set +e
  GROK_UPDATE_WRAPPED=1 "$bin" "$@"
  rc=$?
  set -e
  adopt_self_update || true
  if ! bin="$(current_grok_bin)"; then
    die "No grok program is installed yet. Run: bash install.sh"
  fi
  refuse_launcher_binary "$bin"
  if [ "$MODE" = "sdcard" ] && file_contains "$bin" "$RESOLV_NATIVE"; then
    say "The grok program is missing the DNS patch. This happens after 'grok update' replaces the program."
  fi
  if ! patch_grok_binary "$bin" "$MODE" "$SCRIPT_DIR/grok-dns.py"; then
    die "Could not patch grok after the update."
  fi
  neutralize_shadowed_grok || true
  say "If grok still runs the wrong program, run: hash -r"
  say "Or close Termux and open it again."
  exit "$rc"
fi

neutralize_shadowed_grok || true

exec "$bin" "$@" || die "Could not start $bin."
