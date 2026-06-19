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

say()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."

# We deliberately avoid api.github.com here: it's rate-limited to 60 req/hour for
# unauthenticated callers, which trips a 403 for anyone behind a shared IP. Both
# endpoints below are plain github.com web routes with no such limit:
#   1. the /releases/latest redirect tells us the newest tag, and
#   2. /releases/expanded_assets/<tag> lists that release's files.
say "Looking up the latest Whetstone release…"
TAG="$(curl -fsS -o /dev/null -w '%{url_effective}' -L "https://github.com/${REPO}/releases/latest" | sed -E 's#.*/tag/##')"
[ -n "$TAG" ] || die "Couldn't determine the latest release. Are there any published yet?"
ASSET_LIST="$(curl -fsSL "https://github.com/${REPO}/releases/expanded_assets/${TAG}" 2>/dev/null \
  | grep -oE "/${REPO}/releases/download/[^\"]+" | sort -u)"
[ -n "$ASSET_LIST" ] || die "Release ${TAG} has no downloadable assets yet."

# First asset URL whose filename matches a regex (case-insensitive).
asset_url() {
  printf '%s\n' "$ASSET_LIST" \
    | grep -iE "$1" \
    | sed -E "s#^#https://github.com#" \
    | head -n1
}

# Install by extracting the .deb into ~/.local. The .deb binary links against the
# SYSTEM webkit2gtk (it doesn't bundle one), so rendering runs at full GPU speed —
# unlike the AppImage, whose bundled, older webkit causes laggy animations on
# rolling-release distros. Used on Arch and friends.
install_deb_local() {
  local url="$1"
  [ -n "$url" ] || die "No .deb found in the latest release."
  command -v ar >/dev/null 2>&1 || die "'ar' is required (install 'binutils')."

  # The .deb expects system webkit2gtk-4.1 + gtk3 to be present.
  if ! ldconfig -p 2>/dev/null | grep -q "libwebkit2gtk-4.1.so.0"; then
    warn "System webkit2gtk-4.1 not found — install it for the app to run:"
    warn "  sudo pacman -S webkit2gtk-4.1 gtk3 libayatana-appindicator"
  fi

  local tmp; tmp="$(mktemp -d)"
  say "Downloading .deb…"
  curl -fsSL "$url" -o "${tmp}/ws.deb"
  ( cd "$tmp" && ar x ws.deb && tar xf data.tar.* ) || die "Couldn't unpack the .deb."

  local dest="${HOME}/.local"
  install -Dm755 "${tmp}/usr/bin/whetstone" "${dest}/bin/whetstone"
  for png in "${tmp}"/usr/share/icons/hicolor/*/apps/whetstone.png; do
    [ -f "$png" ] || continue
    install -Dm644 "$png" "${dest}/share/icons/hicolor/$(basename "$(dirname "$(dirname "$png")")")/apps/whetstone.png"
  done
  local desk="${dest}/share/applications/whetstone.desktop"
  install -Dm644 "${tmp}"/usr/share/applications/*.desktop "$desk"
  # Point Exec at the absolute path so the menu launcher doesn't depend on PATH.
  sed -i "s|^Exec=.*|Exec=${dest}/bin/whetstone %F|" "$desk"
  update-desktop-database "${dest}/share/applications" >/dev/null 2>&1 || true
  rm -rf "$tmp"

  say "Installed to ${dest}/bin/whetstone (uses your system webkit — full speed)."
  case ":$PATH:" in
    *":${dest}/bin:"*) : ;;
    *) warn "Add ${dest}/bin to your PATH to run 'whetstone' from anywhere." ;;
  esac
}

install_appimage() {
  local url="$1"
  [ -n "$url" ] || die "No AppImage found in the latest release."
  local dest="${HOME}/.local/bin"
  local bin="${dest}/whetstone"
  mkdir -p "$dest"
  say "Downloading AppImage…"
  # Download beside the target, then atomically rename into place. Writing the
  # file directly would fail with "text file busy" (ETXTBSY) when updating while
  # Whetstone is open; a rename swaps the inode, so the running copy is untouched
  # and the next launch picks up the new build.
  local tmp="${bin}.new.$$"
  curl -fsSL "$url" -o "$tmp"
  chmod +x "$tmp"
  mv -f "$tmp" "$bin"
  say "Installed to ${bin}"

  desktop_integration "$bin"

  case ":$PATH:" in
    *":${dest}:"*) : ;;
    *) warn "Add ${dest} to your PATH to run 'whetstone' from anywhere." ;;
  esac
}

# Put Whetstone in the application menu with its real logo: the icon ships inside
# the AppImage, so we extract it and write a .desktop launcher pointing at the
# installed binary. Best-effort — a failure here never aborts the install.
desktop_integration() {
  local bin="$1"
  local apps="${HOME}/.local/share/applications"
  local icondir="${HOME}/.local/share/icons"
  local icon="${icondir}/whetstone.png"
  mkdir -p "$apps" "$icondir"

  local work; work="$(mktemp -d)"
  if ( cd "$work" && "$bin" --appimage-extract >/dev/null 2>&1 ); then
    local src=""
    # Largest themed icon (version-sort, so 256x256 beats 32x32), then a real
    # root-level png (-type f skips the symlinked small one), then .DirIcon.
    src="$(find "$work/squashfs-root/usr/share/icons" -name '*.png' 2>/dev/null | sort -V | tail -n1 || true)"
    [ -n "$src" ] || src="$(find "$work/squashfs-root" -maxdepth 1 -type f -name '*.png' 2>/dev/null | head -n1 || true)"
    [ -n "$src" ] || src="$(readlink -f "$work/squashfs-root/.DirIcon" 2>/dev/null || true)"
    if [ -n "$src" ] && [ -f "$src" ]; then
      install -Dm644 "$src" "$icon"
    else
      warn "Couldn't find the icon inside the AppImage; the launcher will use a generic one."
    fi
  else
    warn "Couldn't extract the AppImage icon; the launcher will use a generic one."
  fi
  rm -rf "$work"

  local icon_field="whetstone"
  [ -f "$icon" ] && icon_field="$icon"

  cat > "${apps}/whetstone.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Whetstone
GenericName=Code Editor
Comment=A fast, beautiful code editor that hones your craft
Exec=${bin} %F
Icon=${icon_field}
Terminal=false
Categories=Development;TextEditor;IDE;Utility;
Keywords=editor;code;whetstone;
StartupNotify=true
StartupWMClass=whetstone
MimeType=text/plain;inode/directory;
EOF
  update-desktop-database "$apps" >/dev/null 2>&1 || true
  say "Added Whetstone to your application menu."
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
      # Arch/CachyOS/Manjaro: install from the .deb so we run against the SYSTEM
      # webkit (full GPU speed). The AppImage's bundled older webkit is laggy on
      # rolling-release graphics stacks.
      install_deb_local "$(asset_url '\.deb$')"
    else
      # Unknown distro: the AppImage is the portable fallback (bundled webkit).
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
