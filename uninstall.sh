#!/data/data/com.termux/files/usr/bin/bash
#
# uninstall.sh — remove the grok commands and installed program files.
# Login and settings in ~/.grok are kept. The DNS file is removed.
#
set -euo pipefail

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "main" ]; then
  printf 'Could not find the uninstall folder.\n' >&2
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
  printf 'Missing %s/common.sh. Delete the grok files by hand.\n' "$SCRIPT_DIR" >&2
  exit 1
fi
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

prefix="$(grok_prefix)"
home="$(grok_home)"

restore_native_backups

say "Removing the grok commands…"
rm -f -- "$prefix/bin/grok" "$prefix/bin/grok-doctor" || die "Could not remove the grok commands from $prefix/bin."

say "Removing grok's program files…"
rm -rf -- "$home/agents/grok" "$home/.grok/versions" || die "Could not remove grok's program files."

dns="$(dns_file_path)"
if [ -e "$dns" ]; then
  if rm -f -- "$dns"; then
    say "Removed $dns."
  else
    say "Could not remove $dns. You can delete that file yourself."
  fi
fi

say "Done. Your login and settings in $home/.grok were kept."
say "To remove those too, run: rm -rf ~/.grok"
