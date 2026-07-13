#!/bin/sh

set -e

# ─────────────────────────────────────────────────────────────────────────────
# ubuntu-gui-toolbox — Ubuntu LTS toolbox for upstream-built GUI apps
#
# Installs:
#   LocalSend — official upstream .deb (Flutter/GTK).
#
# Why this image exists (do not "simplify" it back into udx-toolbox):
#   LocalSend ships a Flutter binary built against an Ubuntu LTS toolchain and
#   has not been rebuilt since 2025-02 (v1.17.0 is still the latest release).
#   On the rolling Arch udx-toolbox (now glibc 2.43) that binary's Dart VM
#   fails to initialise: the GTK window and titlebar map, nothing ever paints,
#   and NOT ONE line reaches stderr. The result is an unusable black window.
#   The identical binary runs correctly on Ubuntu 24.04 (glibc 2.39).
#
#   This was misdiagnosed twice before landing here — it is NOT the NVIDIA
#   passthrough (black with zero NVIDIA libs and Mesa-only EGL), NOT the GPU
#   (black under llvmpipe, XWayland and with Impeller disabled), NOT the app
#   config (black with a fresh profile), and NOT the host image (darktable
#   renders fine in the same Arch container). It is the glibc floor. If you
#   move LocalSend back to Arch, the black window comes back.
#
# Wayland strategy: LocalSend is Flutter/GTK, NOT Chromium. It must NEVER get
# the Chromium/Ozone flags that udx-toolbox patches into Electron .desktop
# files — they are not its argv contract. Host env vars ARE injected (below).
#
# Export-list strategy: identical contract to udx-toolbox — discover the real
# .desktop basename from the package manager, write /etc/distrobox-export.list,
# then assert every entry resolves. dotfiles' init_hook reads that file.
# ─────────────────────────────────────────────────────────────────────────────

# Symlink distrobox shims (docker, podman, flatpak, etc. → host)
./distrobox-shims.sh

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# ─── LocalSend ──────────────────────────────────────────────────────────────
# Pin the version explicitly: the .deb URL is content-addressed by tag, and an
# unpinned "latest" fetch would silently change what ships in the image.
LOCALSEND_VERSION="1.17.0"
LOCALSEND_DEB="LocalSend-${LOCALSEND_VERSION}-linux-x86-64.deb"
LOCALSEND_URL="https://github.com/localsend/localsend/releases/download/v${LOCALSEND_VERSION}/${LOCALSEND_DEB}"

apt-get install -y ca-certificates curl

# Upstream .deb packaging bug — install the Ayatana tray lib EXPLICITLY.
# LocalSend's .deb declares:
#     Depends: libappindicator3-1 | libayatana-appindicator3-1, ...
# Those are ALTERNATIVES, so apt satisfies the FIRST one (libappindicator3-1),
# which on Ubuntu 24.04 ships libappindicator3.so.1 — but the binary is linked
# against libayatana-appindicator3.so.1, which only the SECOND alternative
# provides. Result: `apt-get install ./localsend.deb` "succeeds", and the app
# then dies at startup with
#     error while loading shared libraries: libayatana-appindicator3.so.1
# Installing it up front makes apt pick the alternative that actually satisfies
# the ELF's DT_NEEDED. The ldd assertion at the bottom of this script is the
# backstop if upstream ever changes this again.
apt-get install -y libayatana-appindicator3-1 gir1.2-ayatanaappindicator3-0.1

# 3-retry loop — network flakiness is the default assumption for remote fetches.
cd /tmp
for i in 1 2 3; do
  rm -f "$LOCALSEND_DEB"
  curl -fsSL -o "$LOCALSEND_DEB" "$LOCALSEND_URL" && break
  echo "LocalSend .deb download attempt $i failed, retrying..."
  sleep 3
done
[ -f "$LOCALSEND_DEB" ] || { echo "ERROR: failed to download $LOCALSEND_DEB after 3 attempts"; exit 1; }

# `apt-get install ./file.deb` resolves the .deb's declared dependencies from
# the archive (libayatana-appindicator3-1 for the tray, etc.). A bare
# `dpkg -i` would leave them unsatisfied and the binary would fail to start
# with a bare "error while loading shared libraries" and no window at all.
apt-get install -y "./${LOCALSEND_DEB}"
rm -f "/tmp/${LOCALSEND_DEB}"
cd /

# ─── Host environment variable injector ────────────────────────────────────
# distrobox init=true shadows the host dbus session bus inside the container.
# LocalSend registers a StatusNotifierItem (system tray) over dbus, so without
# the host bus the tray icon never appears on the host bar — and this app is
# configured to minimise to tray, which would make it unreachable.
#
# XDG_CURRENT_DESKTOP is set for parity with udx-toolbox so desktop-integration
# lookups resolve the same way inside both boxes.
HOST_ENV_VARS="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/host/run/user/1000/bus XDG_CURRENT_DESKTOP=niri:GNOME"

apply_host_env_vars() {
  desktop_path="$1"
  [ -f "$desktop_path" ] || { echo "WARN: $desktop_path not found, skipping env injection"; return 0; }

  # Idempotency: skip if already injected
  if grep -q "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/host/run/user" "$desktop_path"; then
    echo "INFO: $desktop_path already has host env vars"
    return 0
  fi

  # Two shapes to handle:
  #   Exec=cmd args...           → Exec=env DBUS_... XDG_... cmd args...
  #   Exec=env VAR=val cmd ...   → Exec=env DBUS_... XDG_... VAR=val cmd ...
  # New vars go BEFORE any existing env vars so they take precedence.
  if grep -qE "^Exec=env " "$desktop_path"; then
    sed -i -E "s|^(Exec=env )(.*)\$|\1${HOST_ENV_VARS} \2|" "$desktop_path"
  else
    sed -i -E "s|^Exec=(.+)\$|Exec=env ${HOST_ENV_VARS} \1|" "$desktop_path"
  fi

  echo "INFO: injected host env vars into $desktop_path"
}

# ─── Discover-then-assert export list ───────────────────────────────────────
# Ask dpkg for the package's real .desktop basenames rather than hardcoding
# them — a hardcoded name that drifts would silently drop the app from the
# host launcher. (udx-toolbox does the same via `pacman -Ql`.)
DEB_PACKAGES="localsend"

EXPORT_LIST_TMP=$(mktemp)

for pkg in $DEB_PACKAGES; do
  echo "── discovering .desktop files for $pkg ──"
  desktop_files=$(dpkg -L "$pkg" 2>/dev/null \
    | grep -E '^/usr/share/applications/.+\.desktop$' || true)

  if [ -z "$desktop_files" ]; then
    echo "ERROR: no /usr/share/applications/*.desktop file found in package $pkg"
    echo "       This means the export list would silently miss this app."
    echo "       Investigate: dpkg -L $pkg"
    exit 1
  fi

  for d in $desktop_files; do
    base=$(basename "$d" .desktop)
    echo "  found: $base"
    echo "$base" >> "$EXPORT_LIST_TMP"
    apply_host_env_vars "$d"
  done
done

# Dedupe and write final list
sort -u "$EXPORT_LIST_TMP" > /etc/distrobox-export.list
rm -f "$EXPORT_LIST_TMP"

# Assertion gate: every line in the list must resolve to a real .desktop.
# A silent miss here = app disappears from the host menu, so fail the build.
echo "── asserting /etc/distrobox-export.list entries resolve ──"
while IFS= read -r app; do
  [ -z "$app" ] && continue
  if [ ! -f "/usr/share/applications/${app}.desktop" ]; then
    echo "ASSERT FAIL: /usr/share/applications/${app}.desktop missing for list entry '$app'"
    exit 1
  fi
  echo "  ok: $app"
done < /etc/distrobox-export.list

# Assertion gate: the Flutter binary must exist and have no unresolved libs.
# NOTE: upstream's .deb installs the binary as `localsend_app`, NOT `localsend`
# — do not "fix" this to `localsend`, it will silently resolve to nothing and
# turn this gate into a no-op. Resolved from dpkg rather than hardcoded so a
# rename upstream fails the build loudly instead of skipping the check.
# The /usr/bin entry is a SYMLINK created by the package's postinst, so it does
# NOT appear in `dpkg -L` — resolve via PATH first, then fall back to the real
# payload path inside the package listing.
LOCALSEND_BIN=$(command -v localsend_app 2>/dev/null || true)
if [ -z "$LOCALSEND_BIN" ]; then
  LOCALSEND_BIN=$(dpkg -L localsend | grep -E '/localsend_app$' | head -1)
fi
if [ -z "$LOCALSEND_BIN" ] || [ ! -x "$LOCALSEND_BIN" ]; then
  echo "ASSERT FAIL: localsend_app executable not found after install"
  echo "             command -v localsend_app → '$(command -v localsend_app 2>/dev/null)'"
  echo "             dpkg -L localsend | grep localsend_app:"
  dpkg -L localsend | grep -E 'localsend_app' || true
  exit 1
fi
# ldd the REAL binary, not the /usr/bin symlink. The Flutter bundle finds its
# own plugins (libflutter_linux_gtk.so et al) via an $ORIGIN-relative RPATH, so
# ldd'ing the symlink resolves $ORIGIN to /usr/bin and reports every bundled
# plugin as "not found" — a false alarm. Resolving the symlink first makes the
# check assert what we actually care about: the SYSTEM libs the ELF needs
# (notably libayatana-appindicator3.so.1, whose absence is a silent killer).
LOCALSEND_REAL=$(readlink -f "$LOCALSEND_BIN")
if ldd "$LOCALSEND_REAL" 2>/dev/null | grep -q "not found"; then
  echo "ASSERT FAIL: $LOCALSEND_REAL has unresolved shared libraries:"
  ldd "$LOCALSEND_REAL" | grep "not found"
  exit 1
fi
echo "  ok: $LOCALSEND_REAL exists and links cleanly"

# Clean up apt caches to keep the image small
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "ubuntu-gui-toolbox setup complete"
