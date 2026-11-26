#!/data/data/com.termux/files/usr/bin/bash
# Shared helpers for the Termux grok installer, launcher, and doctor.
#
# The patched grok program always reads the 16-byte path /sdcard/.grokdns.
# Tests can point GROK_DNS_FILE and GROK_SYSTEM_RESOLV at fake files.
# GROK_DNS is a space-separated list of DNS servers for a real install.
# GROK_MOCK_GETPROP=1 makes GROK_PROP_DNS1 and GROK_PROP_DNS2 stand in for
# `getprop net.dns1` / `getprop net.dns2`.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  printf 'This file is a library. Run install.sh or launcher.sh.\n' >&2
  exit 1
fi

if [ -n "${GROK_COMMON_LOADED:-}" ]; then
  return 0
fi
GROK_COMMON_LOADED=1

set -euo pipefail

# Both strings are 16 bytes, so the swap does not change the program size.
RESOLV_NATIVE="/etc/resolv.conf"
RESOLV_SDCARD="/sdcard/.grokdns"
if [ "${#RESOLV_NATIVE}" -ne 16 ] || [ "${#RESOLV_SDCARD}" -ne 16 ]; then
  printf '[grok-native] ERROR: DNS path strings must be 16 bytes.\n' >&2
  exit 1
fi

say() {
  printf '\033[1;32m[grok-native]\033[0m %s\n' "$*"
}

err() {
  printf '\033[1;31m[grok-native] ERROR:\033[0m %s\n' "$*" >&2
}

die() {
  err "$@"
  exit 1
}

ok() {
  printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"
}

bad() {
  printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"
}

die_storage() {
  local dest="$1"
  die "Cannot write $dest. Termux does not have storage permission. Run termux-setup-storage, allow storage, then run this installer again."
}

trim() {
  local s="$1"
  s="${s//$'\r'/}"
  s="${s//[[:space:]]/}"
  printf '%s' "$s"
}

valid_ip() {
  local ip="$1" o i
  [ -n "$ip" ] || return 1
  case "$ip" in
    0.0.0.0|127.0.0.1|::|::1) return 1 ;;
  esac
  if [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    for i in 1 2 3 4; do
      o="${BASH_REMATCH[$i]}"
      if [ "${#o}" -gt 1 ] && [ "${o:0:1}" = "0" ]; then
        return 1
      fi
      if [ "$o" -gt 255 ]; then
        return 1
      fi
    done
    return 0
  fi
  if [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] && [[ "$ip" == *:* ]] && [[ "$ip" =~ [0-9A-Fa-f] ]]; then
    return 0
  fi
  return 1
}

is_seen() {
  local needle="$1" item
  shift
  for item in "$@"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

grok_home() {
  if [ -n "${GROK_HOME:-}" ]; then
    printf '%s\n' "$GROK_HOME"
  else
    printf '%s\n' "${HOME:-/data/data/com.termux/files/home}"
  fi
}

grok_prefix() {
  if [ -n "${GROK_PREFIX:-}" ]; then
    printf '%s\n' "$GROK_PREFIX"
  elif [ -n "${PREFIX:-}" ]; then
    printf '%s\n' "$PREFIX"
  else
    printf '%s\n' "/data/data/com.termux/files/usr"
  fi
}

grok_versions_dir() {
  printf '%s/.grok/versions\n' "$(grok_home)"
}

grok_agents_dir() {
  printf '%s/agents/grok\n' "$(grok_home)"
}

dns_file_path() {
  printf '%s\n' "${GROK_DNS_FILE:-$RESOLV_SDCARD}"
}

system_resolv_path() {
  printf '%s\n' "${GROK_SYSTEM_RESOLV:-/etc/resolv.conf}"
}

tmp_files=()

register_tmp() {
  tmp_files+=("$1")
}

cleanup() {
  local f
  if [ "${#tmp_files[@]}" -eq 0 ]; then
    return 0
  fi
  for f in "${tmp_files[@]}"; do
    if [ -n "$f" ]; then
      # A cleanup problem must not hide the error that stopped the install.
      rm -rf -- "$f" || true
    fi
  done
}

file_contains() {
  local f="$1" text="$2"
  if [ ! -f "$f" ] || [ ! -r "$f" ]; then
    return 1
  fi
  grep -a -F -q -- "$text" "$f"
}

dns_file_valid() {
  local f="$1" line ns
  [ -n "$f" ] || return 1
  [ -f "$f" ] && [ -r "$f" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^[[:space:]]*nameserver[[:space:]]+([^[:space:]#]+) ]]; then
      ns="$(trim "${BASH_REMATCH[1]}")"
      if valid_ip "$ns"; then
        return 0
      fi
    fi
  done < "$f"
  return 1
}

system_resolv_ok() {
  dns_file_valid "$(system_resolv_path)"
}

dns_server_list() {
  local f="$1" line ns out=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^[[:space:]]*nameserver[[:space:]]+([^[:space:]#]+) ]]; then
      ns="$(trim "${BASH_REMATCH[1]}")"
      if valid_ip "$ns"; then
        if [ -n "$out" ]; then
          out="$out, $ns"
        else
          out="$ns"
        fi
      fi
    fi
  done < "$f"
  printf '%s\n' "$out"
  return 0
}

# Prints the phone DNS servers, one per line. Missing values are normal.
phone_dns_servers() {
  local gp=""
  if [ "${GROK_MOCK_GETPROP:-}" = "1" ]; then
    printf '%s\n' "${GROK_PROP_DNS1:-}"
    printf '%s\n' "${GROK_PROP_DNS2:-}"
    return 0
  fi
  if command -v getprop >/dev/null 2>&1; then
    gp="$(command -v getprop)"
  elif [ -x /system/bin/getprop ]; then
    gp="/system/bin/getprop"
  else
    return 0
  fi
  # A missing Android property is not a failure. Callers use public DNS.
  "$gp" net.dns1 || true
  "$gp" net.dns2 || true
  return 0
}

# Fills the named array with the servers we should write.
collect_nameservers() {
  local s raw
  local -a incoming=()
  local -n _dest=$1
  _dest=()

  if [ -n "${GROK_DNS+x}" ] && [ -z "${GROK_DNS}" ]; then
    die "GROK_DNS is empty. Example: GROK_DNS=\"1.1.1.1 8.8.8.8\""
  fi

  if [ -n "${GROK_DNS:-}" ]; then
    read -r -a incoming <<< "$GROK_DNS"
    if [ "${#incoming[@]}" -eq 0 ]; then
      die "GROK_DNS is empty. Example: GROK_DNS=\"1.1.1.1 8.8.8.8\""
    fi
    for s in "${incoming[@]}"; do
      if ! valid_ip "$s"; then
        die "GROK_DNS has an address I cannot use: $s. Example: GROK_DNS=\"1.1.1.1 8.8.8.8\""
      fi
      if [ "${#_dest[@]}" -eq 0 ] || ! is_seen "$s" "${_dest[@]}"; then
        _dest+=("$s")
      fi
    done
    return 0
  fi

  raw="$(phone_dns_servers)"
  while IFS= read -r s || [ -n "$s" ]; do
    s="$(trim "$s")"
    if [ -n "$s" ] && valid_ip "$s"; then
      if [ "${#_dest[@]}" -eq 0 ] || ! is_seen "$s" "${_dest[@]}"; then
        _dest+=("$s")
      fi
    fi
  done <<< "$raw"

  if [ "${#_dest[@]}" -eq 0 ]; then
    _dest+=("1.1.1.1" "8.8.8.8")
  fi
}

write_dns_file() {
  local dest="$1" dir tmp ns
  local -a servers=()
  collect_nameservers servers
  if [ "${#servers[@]}" -eq 0 ]; then
    die "No DNS servers to write."
  fi
  dir="$(dirname "$dest")"
  if [ ! -d "$dir" ]; then
    die_storage "$dest"
  fi
  # mktemp prints the error on stderr. Show it, then the plain-language line.
  if ! tmp="$(mktemp "$dir/.grokdns.XXXXXX" 2>&1)"; then
    err "$tmp"
    die_storage "$dest"
  fi
  register_tmp "$tmp"
  : >"$tmp" || die_storage "$dest"
  for ns in "${servers[@]}"; do
    printf 'nameserver %s\n' "$ns" >>"$tmp" || die_storage "$dest"
  done
  if ! dns_file_valid "$tmp"; then
    die "Internal error: the DNS file I built is not valid."
  fi
  if ! mv -f -- "$tmp" "$dest"; then
    rm -f -- "$tmp"
    die_storage "$dest"
  fi
  # /sdcard often ignores chmod. The file is still readable by this user.
  if ! chmod 644 "$dest"; then
    say "Note: could not change permissions on $dest. That is normal on some phones."
  fi
  say "Wrote DNS servers to $dest."
}

# Keeps a valid DNS file unless GROK_DNS is set. Otherwise writes one.
ensure_dns_file() {
  local dest
  dest="$(dns_file_path)"
  if [ -z "${GROK_DNS:-}" ] && dns_file_valid "$dest"; then
    return 0
  fi
  write_dns_file "$dest"
}

verify_mode() {
  local bin="$1" mode="$2"
  if [ "$mode" = "sdcard" ]; then
    if file_contains "$bin" "$RESOLV_SDCARD" && ! file_contains "$bin" "$RESOLV_NATIVE"; then
      return 0
    fi
    return 1
  fi
  if file_contains "$bin" "$RESOLV_NATIVE" && ! file_contains "$bin" "$RESOLV_SDCARD"; then
    return 0
  fi
  return 1
}

# Swaps the 16-byte DNS path. Already-correct files are left untouched,
# including any backup from an earlier patch.
patch_grok_binary() {
  local bin="$1" mode="$2" py="$3"
  local target other backup s1 s2 bad_patch
  case "$mode" in
    sdcard)
      target="$RESOLV_SDCARD"
      other="$RESOLV_NATIVE"
      ;;
    native)
      target="$RESOLV_NATIVE"
      other="$RESOLV_SDCARD"
      ;;
    *)
      err "Unknown DNS mode: $mode"
      return 1
      ;;
  esac

  if [ ! -f "$bin" ]; then
    err "Grok program not found: $bin"
    return 1
  fi
  if [ ! -r "$bin" ]; then
    err "Cannot read the grok program: $bin"
    return 1
  fi
  if file_contains "$bin" "$target" && ! file_contains "$bin" "$other"; then
    return 0
  fi
  if ! file_contains "$bin" "$other"; then
    err "Cannot patch $bin. It does not contain $other or $target."
    return 1
  fi
  if [ ! -w "$bin" ]; then
    err "Cannot modify the grok program: $bin"
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    err "python3 is not installed. Run: pkg install -y python"
    return 1
  fi
  if [ ! -f "$py" ]; then
    err "Missing the patch program: $py"
    return 1
  fi

  backup="${bin}.bak"
  if ! cp -f -- "$bin" "$backup"; then
    err "Could not save a backup at $backup."
    return 1
  fi
  if ! python3 "$py" "$bin" "$mode"; then
    err "The DNS patch program failed."
    if ! cp -f -- "$backup" "$bin"; then
      err "Could not restore $bin from $backup."
    fi
    return 1
  fi

  bad_patch=0
  if ! file_contains "$bin" "$target"; then
    bad_patch=1
  fi
  if file_contains "$bin" "$other"; then
    bad_patch=1
  fi
  if [ "$bad_patch" -eq 1 ]; then
    err "The DNS patch did not stick. Expected $target in $bin."
    if ! cp -f -- "$backup" "$bin"; then
      err "Could not restore $bin from $backup."
    fi
    return 1
  fi

  if ! s1="$(wc -c < "$backup" | tr -d '[:space:]')"; then
    err "Could not measure $backup."
    return 1
  fi
  if ! s2="$(wc -c < "$bin" | tr -d '[:space:]')"; then
    err "Could not measure $bin."
    return 1
  fi
  if [ "$s1" != "$s2" ]; then
    err "The DNS patch changed the file size ($s1 to $s2). That should not happen."
    if ! cp -f -- "$backup" "$bin"; then
      err "Could not restore $bin from $backup."
    fi
    return 1
  fi

  say "Saved a backup here: $backup"
  say "Applied the DNS patch. grok will read $target."
  return 0
}

# stable, alpha, and the official installer also allow a suffix such as 1.2.3-rc.1.
is_grok_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$ ]]
}

list_versions() {
  local versions="$1" f base
  [ -d "$versions" ] || return 0
  for f in "$versions"/*; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if is_grok_version "$base"; then
      printf '%s\n' "$base"
    fi
  done
  return 0
}

current_grok_bin() {
  local versions verified latest
  versions="$(grok_versions_dir)"
  if [ ! -d "$versions" ]; then
    return 1
  fi
  if [ -f "$versions/.verified" ]; then
    verified="$(tr -d '[:space:]' < "$versions/.verified")"
    if is_grok_version "$verified" && [ -f "$versions/$verified" ]; then
      printf '%s\n' "$versions/$verified"
      return 0
    fi
  fi
  if ! latest="$(list_versions "$versions" | sort -V | tail -n 1)"; then
    return 1
  fi
  if [ -n "$latest" ] && [ -f "$versions/$latest" ]; then
    printf '%s\n' "$versions/$latest"
    return 0
  fi
  return 1
}

storage_writable() {
  local dir probe
  dir="$(dirname "$(dns_file_path)")"
  if [ ! -d "$dir" ]; then
    return 1
  fi
  probe="$dir/.grok-write-test.$$"
  if ! printf 'ok\n' >"$probe"; then
    rm -f -- "$probe"
    return 1
  fi
  rm -f -- "$probe"
}

termux_source_label() {
  case "${TERMUX_APK_RELEASE:-}" in
    F_DROID) printf 'F-Droid\n' ;;
    GITHUB) printf 'GitHub\n' ;;
    GOOGLE_PLAYSTORE|GOOGLE_PLAY|PLAYSTORE|PLAY_STORE) printf 'Play Store (too old)\n' ;;
    "") printf 'not detected\n' ;;
    *) printf '%s\n' "$TERMUX_APK_RELEASE" ;;
  esac
}

# True (exit 0) when this is the frozen Play Store app or a dead mirror.
termux_is_old() {
  local release prefix sources d
  release="${TERMUX_APK_RELEASE:-}"
  case "$release" in
    GOOGLE_PLAYSTORE|GOOGLE_PLAY|PLAYSTORE|PLAY_STORE)
      return 0
      ;;
  esac
  prefix="$(grok_prefix)"
  sources="$prefix/etc/apt/sources.list"
  if [ -f "$sources" ] && grep -Eq 'bintray\.com|://termux\.net' "$sources"; then
    return 0
  fi
  d="$prefix/etc/apt/sources.list.d"
  if [ -d "$d" ] && grep -REq 'bintray\.com|://termux\.net' "$d"; then
    return 0
  fi
  return 1
}

print_termux_fix() {
  printf '  The Play Store Termux app is too old, and some package mirrors are shut down.\n'
  printf '  Install Termux from F-Droid if you can. Then run:\n'
  printf '    termux-change-repo\n'
  printf '    pkg upgrade\n'
  printf '  Then run this installer again.\n'
}

# True when this path is the Termux launcher (or a shortcut to it).
is_our_launcher() {
  local path="$1" real ours agents candidate
  [ -n "$path" ] || return 1
  [ -e "$path" ] || [ -L "$path" ] || return 1
  ours="$(grok_prefix)/bin/grok"
  if [ "$path" = "$ours" ]; then
    return 0
  fi
  real="$(readlink -f -- "$path" 2>/dev/null || true)"
  [ -n "$real" ] || return 1
  for candidate in "$ours" "$(grok_agents_dir)/launcher.sh" "${GROK_SCRIPT_DIR:-}/launcher.sh"; do
    [ -n "$candidate" ] || continue
    [ -e "$candidate" ] || [ -L "$candidate" ] || continue
    agents="$(readlink -f -- "$candidate" 2>/dev/null || true)"
    if [ -n "$agents" ] && [ "$real" = "$agents" ]; then
      return 0
    fi
  done
  return 1
}

# Prints each grok executable from `type -a`, in PATH order.
list_grok_paths() {
  local line path
  while IFS= read -r line; do
    case "$line" in
      "grok is hashed ("*")")
        path="${line#grok is hashed (}"
        path="${path%)}"
        printf '%s\n' "$path"
        ;;
      "grok is "/*)
        path="${line#grok is }"
        printf '%s\n' "$path"
        ;;
    esac
  done < <(type -a grok 2>/dev/null || true)
}

path_under_home() {
  local path="$1" home real
  home="$(grok_home)"
  case "$path" in
    "$home"/*) return 0 ;;
  esac
  real="$(readlink -f -- "$path" 2>/dev/null || true)"
  case "$real" in
    "$home"/*) return 0 ;;
  esac
  return 1
}

# The official installer prepends ~/.grok/bin. A later copy on PATH does not hide us.
is_official_path_line() {
  local line="$1" trimmed dollar='$'
  trimmed="${line#"${line%%[![:space:]]*}"}"
  case "$trimmed" in
    ''|'#'*) return 1 ;;
  esac
  # dollar is literal: these are lines as written in the shell rc file.
  case "$trimmed" in
    *".grok/bin:${dollar}PATH"*|*".grok/bin:${dollar}{PATH}"*|*fish_add_path*.grok/bin*)
      return 0
      ;;
  esac
  return 1
}

grok_backup_list() {
  printf '%s/.grok/termux-native-backups.tsv\n' "$(grok_home)"
}

record_backup() {
  local orig="$1" backup="$2" list line
  list="$(grok_backup_list)"
  mkdir -p -- "$(dirname "$list")" || return 1
  line="$(printf '%s\t%s' "$orig" "$backup")"
  if [ -f "$list" ] && grep -F -x -q -- "$line" "$list"; then
    return 0
  fi
  printf '%s\n' "$line" >>"$list"
}

# Comments out PATH lines that put ~/.grok/bin first. Backs the file up once.
neutralize_rc_file() {
  local file="$1" real home tmp line changed backup
  [ -e "$file" ] || [ -L "$file" ] || return 0
  home="$(grok_home)"
  if [ -L "$file" ]; then
    real="$(readlink -f -- "$file" 2>/dev/null || true)"
    case "$real" in
      "$home"/*) file="$real" ;;
      *)
        say "WARNING: $1 is a shortcut outside the home folder. It was left as it is."
        return 0
        ;;
    esac
  fi
  [ -f "$file" ] || return 0
  changed=0
  while IFS= read -r line || [ -n "$line" ]; do
    if is_official_path_line "$line"; then
      changed=1
      break
    fi
  done <"$file"
  if [ "$changed" -eq 0 ]; then
    return 0
  fi
  if [ ! -w "$file" ]; then
    say "WARNING: cannot edit $file. The official grok PATH line is still active."
    return 1
  fi
  backup="${file}.grok-native-bak"
  if [ ! -e "$backup" ] && [ ! -L "$backup" ]; then
    if ! cp -p -- "$file" "$backup"; then
      say "WARNING: could not back up $file."
      return 1
    fi
    record_backup "$file" "$backup" || return 1
  fi
  tmp="$(mktemp)" || return 1
  register_tmp "$tmp"
  : >"$tmp" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if is_official_path_line "$line"; then
      printf '# grok-termux-native: %s\n' "$line" >>"$tmp" || return 1
    else
      printf '%s\n' "$line" >>"$tmp" || return 1
    fi
  done <"$file"
  if ! mv -f -- "$tmp" "$file"; then
    say "WARNING: could not update $file."
    return 1
  fi
  say "Commented the official grok PATH line in $file."
  say "Backup: $backup"
  return 0
}

launcher_link_target() {
  local ours agents
  ours="$(grok_prefix)/bin/grok"
  if [ -e "$ours" ] || [ -L "$ours" ]; then
    printf '%s\n' "$ours"
    return 0
  fi
  agents="$(grok_agents_dir)/launcher.sh"
  if [ -f "$agents" ]; then
    printf '%s\n' "$agents"
    return 0
  fi
  if [ -n "${GROK_SCRIPT_DIR:-}" ] && [ -f "$GROK_SCRIPT_DIR/launcher.sh" ]; then
    printf '%s\n' "$GROK_SCRIPT_DIR/launcher.sh"
    return 0
  fi
  return 1
}

# Replaces one shadowed grok under the home folder with a shortcut to our launcher.
point_at_launcher() {
  local path="$1" launcher="$2" backup prefix
  [ -e "$path" ] || [ -L "$path" ] || return 0
  if is_our_launcher "$path"; then
    return 0
  fi
  prefix="$(grok_prefix)"
  if [ "$path" = "$prefix/bin/grok" ] || [ "$path" = "$prefix/bin/grok-doctor" ]; then
    return 0
  fi
  if ! path_under_home "$path"; then
    say "WARNING: $path is earlier on PATH than the Termux launcher. It was left in place."
    printf '  Fix: mv %s %s.viejo; hash -r\n' "$path" "$path" >&2
    return 0
  fi
  backup="${path}.viejo"
  if [ ! -w "$(dirname "$path")" ]; then
    say "WARNING: cannot change $path."
    printf '  Fix: mv ~/.grok/bin/grok ~/.grok/bin/grok.viejo; hash -r\n' >&2
    return 1
  fi
  if [ ! -e "$backup" ] && [ ! -L "$backup" ]; then
    if ! mv -f -- "$path" "$backup"; then
      say "WARNING: could not move $path aside."
      return 1
    fi
    record_backup "$path" "$backup" || return 1
    say "Backup: $backup"
  else
    if ! rm -f -- "$path"; then
      say "WARNING: could not replace $path."
      return 1
    fi
  fi
  if ! ln -sfn -- "$launcher" "$path"; then
    say "WARNING: could not point $path at the Termux launcher."
    return 1
  fi
  say "Pointed $path at the Termux launcher."
  return 0
}

# Makes the Termux launcher the grok people actually run. Safe to repeat.
neutralize_shadowed_grok() {
  local launcher path rc=0 official
  if ! launcher="$(launcher_link_target)"; then
    say "WARNING: the Termux launcher is not installed yet."
    return 1
  fi
  neutralize_rc_file "$(grok_home)/.bashrc" || rc=1
  neutralize_rc_file "$(grok_home)/.profile" || rc=1
  neutralize_rc_file "$(grok_home)/.zshrc" || rc=1
  official="$(grok_home)/.grok/bin/grok"
  if [ -e "$official" ] || [ -L "$official" ]; then
    point_at_launcher "$official" "$launcher" || rc=1
  fi
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if is_our_launcher "$path"; then
      break
    fi
    point_at_launcher "$path" "$launcher" || rc=1
  done < <(list_grok_paths)
  return "$rc"
}

# So `grok update` restarts the real program, not this launcher.
prepare_link_for_update() {
  local real="$1" link
  link="$(grok_home)/.grok/bin/grok"
  mkdir -p -- "$(dirname "$link")" || return 1
  if [ -L "$link" ] && ! is_our_launcher "$link"; then
    return 0
  fi
  if [ -e "$link" ] || [ -L "$link" ]; then
    if is_our_launcher "$link"; then
      rm -f -- "$link" || return 1
    elif [ ! -e "${link}.viejo" ] && [ ! -L "${link}.viejo" ]; then
      mv -f -- "$link" "${link}.viejo" || return 1
      record_backup "$link" "${link}.viejo" || return 1
    else
      rm -f -- "$link" || return 1
    fi
  fi
  ln -sfn -- "$real" "$link"
}

read_config_channel() {
  local cfg="$1" line section="" value
  [ -f "$cfg" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      \[cli\]*) section="cli" ;;
      \[*\]) section="" ;;
    esac
    [ "$section" = "cli" ] || continue
    case "$line" in
      [[:space:]]*channel[[:space:]]*=*) ;;
      *) continue ;;
    esac
    value="${line#*=}"
    value="$(trim "$value")"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    case "$value" in
      stable|alpha|enterprise)
        printf '%s\n' "$value"
        return 0
        ;;
    esac
  done <"$cfg"
  return 1
}

# GROK_CHANNEL, then config.toml, then the channel file, then stable.
read_grok_channel() {
  local c cfg
  if [ -n "${GROK_CHANNEL+x}" ]; then
    printf '%s\n' "$GROK_CHANNEL"
    return 0
  fi
  cfg="$(grok_home)/.grok/config.toml"
  if c="$(read_config_channel "$cfg")"; then
    printf '%s\n' "$c"
    return 0
  fi
  cfg="$(grok_versions_dir)/.channel"
  if [ -f "$cfg" ]; then
    c="$(tr -d '[:space:]' <"$cfg")"
    case "$c" in
      stable|alpha|enterprise)
        printf '%s\n' "$c"
        return 0
        ;;
    esac
  fi
  printf '%s\n' "stable"
}

channel_for_invocation() {
  local channel="$1" arg
  shift
  for arg in "$@"; do
    case "$arg" in
      --alpha) channel="alpha" ;;
      --stable) channel="stable" ;;
      --enterprise) channel="enterprise" ;;
    esac
  done
  case "$channel" in
    stable|alpha|enterprise) ;;
    *) channel="stable" ;;
  esac
  printf '%s\n' "$channel"
}

save_grok_channel() {
  local channel="$1" cfg dir tmp
  case "$channel" in
    stable|alpha|enterprise) ;;
    *)
      err "GROK_CHANNEL must be stable, alpha, or enterprise. Got: $channel"
      return 1
      ;;
  esac
  dir="$(grok_versions_dir)"
  mkdir -p -- "$dir" "$(grok_home)/.grok" || return 1
  printf '%s\n' "$channel" >"$dir/.channel" || return 1
  cfg="$(grok_home)/.grok/config.toml"
  tmp="$(mktemp)" || return 1
  register_tmp "$tmp"
  if [ -f "$cfg" ]; then
    awk -v channel="$channel" '
      BEGIN { saw = 0 }
      /^\[cli\][[:space:]]*(#.*)?$/ {
        print
        print "channel = \"" channel "\""
        saw = 1
        in_cli = 1
        next
      }
      /^\[/ { in_cli = 0 }
      in_cli && /^[[:space:]]*channel[[:space:]]*=/ { next }
      { print }
      END {
        if (!saw) {
          print ""
          print "[cli]"
          print "channel = \"" channel "\""
        }
      }
    ' "$cfg" >"$tmp" || return 1
  else
    printf '[cli]\nchannel = "%s"\n' "$channel" >"$tmp" || return 1
  fi
  mv -f -- "$tmp" "$cfg" || return 1
}

# grok update points ~/.grok/bin/grok at a new download. Copy that into versions/.
adopt_self_update() {
  local home bin upd base uver dest verified current ver_out
  home="$(grok_home)"
  bin="$home/.grok/bin/grok"
  if [ ! -e "$bin" ] && [ ! -L "$bin" ]; then
    return 0
  fi
  if is_our_launcher "$bin"; then
    return 0
  fi
  upd="$(readlink -f -- "$bin" 2>/dev/null || true)"
  [ -n "$upd" ] || return 0
  [ -f "$upd" ] || return 0
  if is_our_launcher "$upd"; then
    return 0
  fi
  base="$(basename "$upd")"
  uver=""
  case "$base" in
    grok-*-linux-aarch64)
      uver="${base#grok-}"
      uver="${uver%-linux-aarch64}"
      ;;
    grok-linux-aarch64)
      if command -v timeout >/dev/null 2>&1; then
        ver_out="$(timeout -s KILL 20 "$upd" --version 2>/dev/null || true)"
      else
        ver_out="$("$upd" --version 2>/dev/null || true)"
      fi
      if [[ "$ver_out" =~ ([0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?) ]]; then
        uver="${BASH_REMATCH[1]}"
      fi
      ;;
    *) return 0 ;;
  esac
  if ! is_grok_version "$uver"; then
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
    current="$(tr -d '[:space:]' <"$verified")"
  fi
  if [ "$current" != "$uver" ]; then
    printf '%s\n' "$uver" >"$verified" || die "Could not write $verified."
    say "Switched to grok $uver."
  fi
}

check_grok_command() {
  local cmd
  if ! cmd="$(command -v grok 2>/dev/null)"; then
    bad "Command: grok is not on PATH."
    printf '  Fix: mv ~/.grok/bin/grok ~/.grok/bin/grok.viejo; hash -r\n'
    printf '  Then run: bash install.sh\n'
    return 1
  fi
  if is_our_launcher "$cmd"; then
    ok "Command: grok is the Termux launcher ($cmd)."
    return 0
  fi
  bad "Command: grok is $cmd, not the Termux launcher."
  printf '  That copy has no DNS patch, so grok --doctor says: unexpected argument '\''--doctor'\'' found\n'
  printf '  Fix: mv ~/.grok/bin/grok ~/.grok/bin/grok.viejo; hash -r\n'
  printf '  Or close Termux and open it again.\n'
  return 1
}

restore_native_backups() {
  local list line orig backup home f
  home="$(grok_home)"
  list="$(grok_backup_list)"
  if [ -f "$list" ]; then
    while IFS=$'\t' read -r orig backup || [ -n "${orig:-}" ]; do
      [ -n "${orig:-}" ] || continue
      [ -n "${backup:-}" ] || continue
      if [ -e "$backup" ] || [ -L "$backup" ]; then
        mkdir -p -- "$(dirname "$orig")" || die "Could not restore $orig."
        rm -f -- "$orig" || die "Could not restore $orig."
        mv -f -- "$backup" "$orig" || die "Could not restore $orig."
        say "Restored $orig."
      fi
    done <"$list"
    rm -f -- "$list" || true
  fi
  for f in .bashrc .profile .zshrc; do
    backup="$home/${f}.grok-native-bak"
    if [ -e "$backup" ] || [ -L "$backup" ]; then
      rm -f -- "$home/$f" || die "Could not restore $home/$f."
      mv -f -- "$backup" "$home/$f" || die "Could not restore $home/$f."
      say "Restored $home/$f."
    fi
  done
  orig="$home/.grok/bin/grok"
  backup="$home/.grok/bin/grok.viejo"
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    rm -f -- "$orig" || die "Could not restore $orig."
    mv -f -- "$backup" "$orig" || die "Could not restore $orig."
    say "Restored $orig."
  fi
}

doctor() {
  local fail=0 arch label f bin py
  local line ns tried resolved last_err last_ns lookup_out
  printf 'grok doctor\n'
  printf 'Checks this phone so grok can run.\n'

  label="$(termux_source_label)"
  if termux_is_old; then
    bad "Termux source: $label"
    print_termux_fix
    fail=1
  else
    ok "Termux source: $label"
  fi

  if storage_writable; then
    ok "Storage: can write $(dns_file_path)."
  elif system_resolv_ok; then
    ok "Storage: not required, because a system DNS file is in use."
  else
    bad "Storage: cannot write $(dns_file_path). Run termux-setup-storage and allow storage."
    fail=1
  fi

  f=""
  if system_resolv_ok; then
    f="$(system_resolv_path)"
    ok "DNS file: using the system file $f ($(dns_server_list "$f"))."
  elif dns_file_valid "$(dns_file_path)"; then
    f="$(dns_file_path)"
    ok "DNS file: $f ($(dns_server_list "$f"))."
  else
    bad "DNS file: $(dns_file_path) is missing or has no nameserver. Run termux-setup-storage, then bash install.sh."
    fail=1
  fi

  py="${GROK_SCRIPT_DIR:-}/grok-dns.py"
  if [ -z "$f" ]; then
    bad "DNS lookup: no nameserver to test for api.x.ai."
    fail=1
  elif ! command -v python3 >/dev/null 2>&1; then
    bad "DNS lookup: python3 is missing, so I could not test api.x.ai."
    fail=1
  elif [ ! -f "$py" ]; then
    bad "DNS lookup: missing $py, so I could not test api.x.ai."
    fail=1
  else
    tried=0
    resolved=0
    last_err=""
    last_ns=""
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ ^[[:space:]]*nameserver[[:space:]]+([^[:space:]#]+) ]]; then
        ns="$(trim "${BASH_REMATCH[1]}")"
        if valid_ip "$ns"; then
          tried=$((tried + 1))
          last_ns="$ns"
          if lookup_out="$(python3 "$py" query "$ns" api.x.ai 2>&1)"; then
            ok "DNS lookup: api.x.ai resolves using $ns."
            resolved=1
            break
          fi
          last_err="$lookup_out"
          if [ "$tried" -ge 3 ]; then
            break
          fi
        fi
      fi
    done < "$f"
    if [ "$resolved" -ne 1 ]; then
      bad "DNS lookup: could not resolve api.x.ai using ${last_ns:-the DNS file}. ${last_err}"
      fail=1
    fi
  fi

  if bin="$(current_grok_bin)"; then
    if system_resolv_ok; then
      if file_contains "$bin" "$RESOLV_NATIVE" && ! file_contains "$bin" "$RESOLV_SDCARD"; then
        ok "Binary: using system DNS ($RESOLV_NATIVE)."
      elif file_contains "$bin" "$RESOLV_SDCARD"; then
        bad "Binary: patched for $RESOLV_SDCARD, but a system DNS file exists. Start grok once so it can switch."
        fail=1
      else
        bad "Binary: does not contain a DNS path this installer knows ($bin)."
        fail=1
      fi
    else
      if file_contains "$bin" "$RESOLV_SDCARD" && ! file_contains "$bin" "$RESOLV_NATIVE"; then
        ok "Binary: DNS patch is present ($RESOLV_SDCARD)."
      elif file_contains "$bin" "$RESOLV_NATIVE"; then
        bad "Binary: still has $RESOLV_NATIVE. Start grok once and it will apply the DNS patch."
        fail=1
      else
        bad "Binary: does not contain a DNS path this installer knows ($bin)."
        fail=1
      fi
    fi
  else
    bad "Binary: grok is not installed. Run: bash install.sh"
    fail=1
  fi

  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64)
      ok "Arch: $arch"
      ;;
    *)
      bad "Arch: $arch. This only works on an arm64 phone (aarch64)."
      fail=1
      ;;
  esac

  if ! check_grok_command; then
    fail=1
  fi

  if [ "$fail" -ne 0 ]; then
    say "Some checks failed. Fix the FAIL lines, then run: grok --doctor"
    return 1
  fi
  say "All checks passed."
  return 0
}
