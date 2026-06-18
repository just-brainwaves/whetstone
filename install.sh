#!/usr/bin/env bash
#
# Whetstone installer — grabs the latest release for your platform and installs it.
#
#   curl -fsSL https://raw.githubusercontent.com/just-brainwaves/whetstone/main/install.sh | bash
#
# Linux: installs the .deb (Debian/Ubuntu), .rpm (Fedora) or the .AppImage
# (everything else, including Arch) into ~/.local/bin. macOS: downloads the .dmg
# and opens it. No telemetry, no sudo unless your package manager needs it.

set -euo pipefail

# Public repo that hosts the downloadable releases.
REPO="just-brainwaves/whetstone"
API="https://api.github.com/repos/${REPO}/releases/latest"

say()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."

say "Looking up the latest Whetstone release…"
RELEASE_JSON="$(curl -fsSL "$API")" || die "Couldn't reach GitHub. Are there any releases yet?"

# Pull the first asset URL whose filename matches a regex.
asset_url() {
  printf '%s' "$RELEASE_JSON" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)"/\1/' \
    | grep -iE "$1" \
    | head -n1
}

install_appimage() {
  local url="$1"
  [ -n "$url" ] || die "No AppImage found in the latest release."
  local dest="${HOME}/.local/bin"
  mkdir -p "$dest"
  say "Downloading AppImage…"
  curl -fsSL "$url" -o "${dest}/whetstone"
  chmod +x "${dest}/whetstone"
  say "Installed to ${dest}/whetstone"
  case ":$PATH:" in
    *":${dest}:"*) : ;;
    *) warn "Add ${dest} to your PATH to run 'whetstone' from anywhere." ;;
  esac
}

OS="$(uname -s)"
case "$OS" in
  Linux)
    if [ -r /etc/os-release ]; then . /etc/os-release; fi
    ID_LIKE="${ID_LIKE:-} ${ID:-}"
    if echo "$ID_LIKE" | grep -qiE 'debian|ubuntu'; then
      url="$(asset_url '\.deb$')"
      [ -n "$url" ] || die "No .deb found in the latest release."
      tmp="$(mktemp --suffix=.deb)"
      say "Downloading .deb…"; curl -fsSL "$url" -o "$tmp"
      say "Installing (sudo may prompt)…"
      sudo apt install -y "$tmp" || sudo dpkg -i "$tmp"
      rm -f "$tmp"
    elif echo "$ID_LIKE" | grep -qiE 'fedora|rhel|centos|suse'; then
      url="$(asset_url '\.rpm$')"
      [ -n "$url" ] || die "No .rpm found in the latest release."
      tmp="$(mktemp --suffix=.rpm)"
      say "Downloading .rpm…"; curl -fsSL "$url" -o "$tmp"
      say "Installing (sudo may prompt)…"
      sudo dnf install -y "$tmp" || sudo rpm -i "$tmp"
      rm -f "$tmp"
    elif echo "$ID_LIKE" | grep -qiE 'arch'; then
      warn "On Arch, the cleanest install is the AUR package 'whetstone-bin' (yay -S whetstone-bin)."
      warn "Installing the AppImage instead for now."
      install_appimage "$(asset_url '\.appimage$')"
    else
      install_appimage "$(asset_url '\.appimage$')"
    fi
    ;;
  Darwin)
    arch="$(uname -m)"
    if [ "$arch" = "arm64" ]; then pat='(aarch64|arm64).*\.dmg$'; else pat='(x64|x86_64|intel).*\.dmg$'; fi
    url="$(asset_url "$pat")"
    [ -n "$url" ] || url="$(asset_url '\.dmg$')"
    [ -n "$url" ] || die "No .dmg found in the latest release."
    tmp="$(mktemp -d)/Whetstone.dmg"
    say "Downloading .dmg…"; curl -fsSL "$url" -o "$tmp"
    say "Opening the disk image — drag Whetstone into Applications."
    open "$tmp"
    ;;
  *)
    die "Unsupported OS: $OS. Download manually from https://github.com/${REPO}/releases/latest"
    ;;
esac

say "Done. Launch Whetstone and you're set."
