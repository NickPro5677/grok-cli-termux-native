#!/data/data/com.termux/files/usr/bin/bash
# grok-doctor — print a short checklist for the Termux grok install.
set -euo pipefail

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "main" ]; then
  printf 'Could not find the doctor folder.\n' >&2
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
doctor || exit 1
exit 0
