#!/data/data/com.termux/files/usr/bin/bash
#
# install.sh — xAI Grok Build CLI (grok), native on Termux (aarch64). No proot.
#
# Grok is a static musl program. On Termux it cannot read /etc/resolv.conf,
# so we swap that 16-byte path for /sdcard/.grokdns and keep a nameserver
# file there. A rooted phone that already has /etc/resolv.conf keeps the
# original program.
#
# Safe to run again. If a step fails, this script stops and does not say
# the install succeeded.
#
# GROK_SKIP_PKG and GROK_SKIP_ARCH_CHECK are for the test suite.
#
set -euo pipefail

die() {
  printf '\033[1;31m[grok-native] ERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

RAW="${GROK_RAW_URL:-https://raw.githubusercontent.com/NickPro5677/grok-cli-termux-native/main}"
CHANNEL="${GROK_CHANNEL:-stable}"
PLATFORM="linux-aarch64"
PRIMARY="https://x.ai/cli"
FALLBACK="https://storage.googleapis.com/grok-build-public-artifacts/cli"

# Folder of this file. A symlink is followed. `curl | bash` has no file.
if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "main" ]; then
  SCRIPT_DIR=""
else
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
fi

helpers_ok() {
  local d="$1" f
  [ -n "$d" ] || return 1
  for f in common.sh launcher.sh grok-dns.py grok-doctor.sh uninstall.sh; do
    [ -f "$d/$f" ] || return 1
  done
}

FETCHED=0
if ! helpers_ok "$SCRIPT_DIR"; then
  if ! command -v curl >/dev/null 2>&1; then
    die "curl is not installed, and the helper files are not next to install.sh. Run: pkg install -y curl"
  fi
  SCRIPT_DIR="$(mktemp -d)" || die "Could not create a temp folder."
  FETCHED=1
  printf '[grok-native] Downloading helper files…\n'
  for f in common.sh launcher.sh grok-dns.py grok-doctor.sh uninstall.sh; do
    if ! curl -fsSL --retry 2 --max-time 60 "$RAW/$f" -o "$SCRIPT_DIR/$f"; then
      rm -rf "$SCRIPT_DIR"
      die "Could not download $f. Check your internet connection and run this installer again."
    fi
  done
fi

if [ "$FETCHED" -eq 1 ]; then
  trap 'rm -rf "$SCRIPT_DIR"' EXIT
fi
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
trap cleanup EXIT
if [ "$FETCHED" -eq 1 ]; then
  register_tmp "$SCRIPT_DIR"
fi
GROK_SCRIPT_DIR="$SCRIPT_DIR"

check_environment() {
  local prefix arch
  prefix="$(grok_prefix)"
  if [ ! -d "$prefix" ]; then
    die "This does not look like Termux. The folder $prefix is missing."
  fi
  if [ "${GROK_SKIP_ARCH_CHECK:-}" = "1" ]; then
    return 0
  fi
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) ;;
    *)
      die "This installer only works on arm64 phones (aarch64). This device is $arch."
      ;;
  esac
}

install_deps() {
  local missing="" cmd
  if [ "${GROK_SKIP_PKG:-}" = "1" ]; then
    return 0
  fi
  if ! command -v pkg >/dev/null 2>&1; then
    die "The pkg command is missing. Install Termux from F-Droid and run this installer again."
  fi
  say "Updating the package list…"
  if ! pkg update -y; then
    err "pkg update failed."
    print_termux_fix
    die "Could not update packages. Fix the mirrors, then run this installer again."
  fi
  say "Installing needed programs: python, curl, file, coreutils…"
  if ! pkg install -y python curl file coreutils; then
    err "pkg install failed."
    print_termux_fix
    die "Could not install python, curl, file, and coreutils."
  fi
  for cmd in python3 curl file timeout sort; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing="$missing $cmd"
    fi
  done
  if [ -n "$missing" ]; then
    die "These commands are still missing:$missing. Run: termux-change-repo && pkg upgrade && pkg install -y python curl file coreutils"
  fi
}

download_to() {
  local dest="$1" version="$2" url
  if ! : >"$dest"; then
    die "Could not create the temp file $dest."
  fi
  url="${PRIMARY}/grok-${version}-${PLATFORM}"
  say "Downloading grok $version…"
  if curl -fL --retry 2 --max-time 600 -o "$dest" "$url"; then
    return 0
  fi
  say "The first download failed. Trying the backup server…"
  url="${FALLBACK}/grok-${version}-${PLATFORM}"
  if curl -fL --retry 2 --max-time 600 -o "$dest" "$url"; then
    return 0
  fi
  die "Download failed. Check your internet connection and run this installer again."
}

binary_runs() {
  local bin="$1" smoke rc
  if ! command -v timeout >/dev/null 2>&1; then
    err "The timeout command is missing. Run: pkg install -y coreutils"
    return 1
  fi
  smoke="$(mktemp -d)" || {
    err "Could not create a temp folder for the grok test."
    return 1
  }
  register_tmp "$smoke"
  set +e
  HOME="$smoke" timeout -s KILL 25 "$bin" --version >"$smoke/out" 2>&1
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    err "grok --version failed (exit $rc)."
    if [ -s "$smoke/out" ]; then
      # Showing the log must not replace the real failure.
      cat "$smoke/out" >&2 || true
    fi
    return 1
  fi
  return 0
}

prune_old_versions() {
  local versions="$1" current="$2"
  local line prev="" f base stem keep list n
  local -a vers=()
  list="$(mktemp)" || die "Could not create a temp file."
  register_tmp "$list"
  if ! list_versions "$versions" | sort -V >"$list"; then
    die "Could not list old grok versions. Run: pkg install -y coreutils"
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    vers+=("$line")
  done <"$list"
  rm -f -- "$list"
  n="${#vers[@]}"
  if [ "$n" -eq 1 ]; then
    prev="${vers[0]}"
  elif [ "$n" -ge 2 ]; then
    prev="${vers[$((n - 2))]}"
  fi
  for f in "$versions"/*; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in
      .verified) continue ;;
    esac
    stem="$base"
    if [[ "$base" == *.bak ]]; then
      stem="${base%.bak}"
    fi
    keep=0
    if [ "$stem" = "$current" ]; then
      keep=1
    fi
    if [ -n "$prev" ] && [ "$stem" = "$prev" ]; then
      keep=1
    fi
    if [ "$keep" -eq 0 ]; then
      rm -f -- "$f" || die "Could not remove old file $f."
    fi
  done
}

copy_file() {
  local src="$1" dest="$2" mode="$3"
  if ! cp -f -- "$src" "$dest"; then
    die "Could not copy $src to $dest."
  fi
  if ! chmod "$mode" "$dest"; then
    die "Could not set permissions on $dest."
  fi
}

install_commands() {
  local agents prefix
  agents="$(grok_agents_dir)"
  prefix="$(grok_prefix)"
  mkdir -p -- "$agents" "$prefix/bin" || die "Could not create install folders."
  copy_file "$SCRIPT_DIR/common.sh" "$agents/common.sh" 644
  copy_file "$SCRIPT_DIR/grok-dns.py" "$agents/grok-dns.py" 644
  copy_file "$SCRIPT_DIR/launcher.sh" "$agents/launcher.sh" 755
  copy_file "$SCRIPT_DIR/grok-doctor.sh" "$agents/grok-doctor.sh" 755
  copy_file "$SCRIPT_DIR/uninstall.sh" "$agents/uninstall.sh" 755
  if ! ln -sfn "$agents/launcher.sh" "$prefix/bin/grok"; then
    die "Could not create the grok command at $prefix/bin/grok."
  fi
  if ! ln -sfn "$agents/grok-doctor.sh" "$prefix/bin/grok-doctor"; then
    die "Could not create the grok-doctor command at $prefix/bin/grok-doctor."
  fi
  if [ ! -L "$prefix/bin/grok" ] || [ ! -L "$prefix/bin/grok-doctor" ]; then
    die "The grok commands were not installed in $prefix/bin."
  fi
}

install_main() {
  local version="${1:-}" dest mode final tmp file_out need_download
  check_environment

  if termux_is_old; then
    say "WARNING: This Termux looks old, or its package mirrors look broken."
    print_termux_fix
  fi

  if system_resolv_ok; then
    mode="native"
    say "Found a system DNS file at $(system_resolv_path). grok will use that."
  else
    mode="sdcard"
    dest="$(dns_file_path)"
    if [ -z "${GROK_DNS:-}" ] && dns_file_valid "$dest"; then
      say "Using the DNS file that is already at $dest."
    else
      ensure_dns_file
    fi
    if [ "$dest" != "$RESOLV_SDCARD" ]; then
      say "WARNING: DNS file is $dest. The grok program only reads $RESOLV_SDCARD. Leave GROK_DNS_FILE unset on a phone."
    fi
  fi

  install_deps
  # Hide the two sorted lines. If sort -V fails, its own error still shows.
  if ! printf '2\n1\n' | sort -V >/dev/null; then
    die "The sort command cannot sort version numbers. Run: pkg install -y coreutils"
  fi

  if [ -z "$version" ]; then
    say "Looking up the latest ${CHANNEL} version…"
    # -s hides curl's progress meter. -S still prints errors. The body is one version.
    if ! version="$(curl -fsSL --retry 2 --max-time 20 "${PRIMARY}/${CHANNEL}")"; then
      say "Could not reach the first server. Trying the backup server…"
      if ! version="$(curl -fsSL --retry 2 --max-time 20 "${FALLBACK}/${CHANNEL}")"; then
        die "Could not find the latest ${CHANNEL} version. Check your internet connection and run this installer again."
      fi
    fi
  fi
  version="$(printf '%s' "$version" | tr -d '[:space:]')"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "The version '$version' does not look right. Expected something like 1.2.3."
  fi
  say "Version: $version"

  mkdir -p -- "$(grok_versions_dir)" || die "Could not create $(grok_versions_dir)."
  final="$(grok_versions_dir)/$version"
  tmp="$(grok_versions_dir)/$version.tmp"
  register_tmp "$tmp"
  register_tmp "${tmp}.bak"

  need_download=1
  if [ -f "$final" ]; then
    say "grok $version is already on this phone. Checking it…"
    if patch_grok_binary "$final" "$mode" "$SCRIPT_DIR/grok-dns.py" && binary_runs "$final"; then
      say "The installed grok $version works. Skipping the download."
      need_download=0
    else
      say "The installed grok $version is not usable. Downloading it again."
    fi
  fi

  if [ "$need_download" -eq 1 ]; then
    download_to "$tmp" "$version"
    if ! chmod +x "$tmp"; then
      die "Could not make the downloaded file executable."
    fi
    if ! command -v file >/dev/null 2>&1; then
      die "The file command is missing. Run: pkg install -y file"
    fi
    if ! file_out="$(file -- "$tmp" 2>&1)"; then
      die "Could not inspect the downloaded file: $file_out"
    fi
    case "$file_out" in
      *"statically linked"*) ;;
      *) say "WARNING: This grok file may not be a static program. It might still run." ;;
    esac
    if [ "$mode" = "sdcard" ]; then
      say "Patching grok so DNS works without root…"
    else
      say "Checking the grok program's DNS path…"
    fi
    if ! patch_grok_binary "$tmp" "$mode" "$SCRIPT_DIR/grok-dns.py"; then
      die "Could not patch grok. Nothing was installed."
    fi
    if ! binary_runs "$tmp"; then
      die "The downloaded grok program did not start. Nothing was installed."
    fi
    if [ -f "${tmp}.bak" ]; then
      mv -f -- "${tmp}.bak" "${final}.bak" || die "Could not save the backup next to grok."
    fi
    mv -f -- "$tmp" "$final" || die "Could not install grok into $final."
    chmod 700 "$final" || die "Could not set permissions on $final."
  fi

  if ! verify_mode "$final" "$mode"; then
    die "grok was not patched correctly. Run bash install.sh again."
  fi
  printf '%s\n' "$version" >"$(grok_versions_dir)/.verified" || die "Could not write $(grok_versions_dir)/.verified."
  prune_old_versions "$(grok_versions_dir)" "$version"
  install_commands

  say "Installed grok $version."
  say "Run: grok --doctor"
  say "Then try: grok -p \"hello from Termux\""
  say "To sign in, run grok, or set XAI_API_KEY to your key."
  say "To update later, press Ctrl+U inside grok, or run: grok update"
  say "After an update, start grok again. The DNS patch is applied again if it is needed."
}

case "${1:-}" in
  --help|-h)
    cat <<'EOF'
Usage:
  bash install.sh
  bash install.sh 1.2.3
  bash install.sh --doctor

Installs the grok program on Termux.

Before you start, run:
  termux-setup-storage

To choose DNS servers (optional):
  GROK_DNS="1.1.1.1 8.8.8.8" bash install.sh

If this phone already has a valid /sdcard/.grokdns file, it is left as it is
unless you set GROK_DNS.

Check the phone:
  grok --doctor
EOF
    exit 0
    ;;
  --doctor|doctor)
    doctor || exit 1
    exit 0
    ;;
esac

install_main "$@"
