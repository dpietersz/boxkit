#!/bin/sh

set -e

# ─────────────────────────────────────────────────────────────────────────────
# udx-toolbox — unified Arch daily-driver toolbox
#
# Installs: Azure Storage Explorer, Obsidian, Anytype, Legcord, Polypane,
#           Bruno, LocalSend, Ferdium.
#
# Wayland strategy: preemptively patches Electron app .desktop files with
# Wayland-native flags (ozone hint + PipeWire screen capture + Wayland window
# decorations). No NVIDIA-specific flags — NVIDIA passthrough is handled by
# the host at `distrobox create --nvidia` time, not by the image.
#
# Export-list strategy: discovers each app's actual installed .desktop
# basename via `pacman -Ql`, writes /etc/distrobox-export.list from the
# discovered names, then asserts every entry resolves. Build fails if any
# expected .desktop is missing — no silent drift.
# ─────────────────────────────────────────────────────────────────────────────

# Symlink distrobox shims (docker, podman, flatpak, etc. → host)
./distrobox-shims.sh

# Update the container and install base packages
pacman -Syu --noconfirm
grep -v '^#' ./toolbox.packages | xargs pacman -S --noconfirm

# ─── AUR bootstrap ──────────────────────────────────────────────────────────
# makepkg refuses to run as root, so we create a builder user with passwordless
# sudo and install yay (AUR helper) under that account.

useradd -m -s /bin/bash builder || true
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder

cd /tmp
for i in 1 2 3; do
  rm -rf yay 2>/dev/null || true
  git clone https://aur.archlinux.org/yay.git && break
  echo "yay clone attempt $i failed, retrying..."
  sleep 2
done
[ -d "yay" ] || { echo "Failed to clone yay after 3 attempts"; exit 1; }

chown -R builder:builder yay
cd yay
sudo -u builder makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# ─── Application install ────────────────────────────────────────────────────

# yay_install <package> — install one AUR package with 3-retry loop.
yay_install() {
  pkg="$1"
  for i in 1 2 3; do
    if sudo -u builder yay -S --noconfirm "$pkg"; then
      return 0
    fi
    echo "yay -S $pkg attempt $i failed, retrying..."
    sleep 3
  done
  echo "ERROR: failed to install $pkg after 3 attempts"
  return 1
}

# Obsidian: official Arch extra repo (first-class package, preferred over AUR)
pacman -S --noconfirm obsidian

# AUR packages
yay_install storageexplorer
yay_install anytype-bin
yay_install legcord-bin
yay_install polypane
yay_install bruno-bin
yay_install localsend-bin
yay_install ferdium-bin

# ─── Wayland flag patcher (preemptive) ──────────────────────────────────────
# Applied to every Electron app's primary .desktop Exec= line so the apps
# run as Wayland-native windows on niri (no XWayland fallback) and can use
# the xdg-desktop-portal + PipeWire pipeline for screen sharing.
#
# Flags chosen:
#   --ozone-platform-hint=auto         picks Wayland when available, X11 else
#   WaylandWindowDecorations           client-side decorations on Wayland
#   WebRTCPipeWireCapturer +
#   --enable-webrtc-pipewire-capturer  screen share via PipeWire (required on
#                                      Wayland; X11 capture is blocked there)
#
# Explicitly NOT included: VA-API hardware video decode flags. The NVIDIA
# VA-API shim (libva-nvidia-driver) is brittle, has known visual glitches,
# and none of these apps decode meaningful video — zero practical benefit
# and meaningful crash risk on the P14s RTX laptop. NVIDIA GPU compositing
# still works via the host driver libs mounted by `distrobox create --nvidia`.
WAYLAND_FLAGS="--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer --enable-webrtc-pipewire-capturer"

apply_wayland_flags() {
  desktop_path="$1"
  [ -f "$desktop_path" ] || { echo "WARN: $desktop_path not found, skipping flag patch"; return 0; }

  # Idempotency: skip if already patched
  if grep -q -- "--ozone-platform-hint=auto" "$desktop_path"; then
    echo "INFO: $desktop_path already patched"
    return 0
  fi

  # Insert flags after the executable token of the main Exec= line.
  # Captures: \1 = executable path (no spaces); \2 = remainder (args, %U, etc.)
  sed -i -E "s|^Exec=([^[:space:]]+)([[:space:]].*)?\$|Exec=\1 ${WAYLAND_FLAGS}\2|" "$desktop_path"
  echo "INFO: patched $desktop_path"
}

# ─── Discover-then-assert export list ───────────────────────────────────────
# For each installed app package, ask pacman for its real .desktop file
# basenames. Write those to /etc/distrobox-export.list. Then assert each
# entry resolves — build fails if any expected app has no .desktop on disk
# (which would mean the host export would silently miss it).

EXPORTED_PACKAGES="obsidian anytype-bin legcord-bin polypane bruno-bin localsend-bin ferdium-bin storageexplorer"

EXPORT_LIST_TMP=$(mktemp)
for pkg in $EXPORTED_PACKAGES; do
  echo "── discovering .desktop files for $pkg ──"
  desktop_files=$(pacman -Ql "$pkg" 2>/dev/null \
    | awk '$2 ~ "^/usr/share/applications/.+\\.desktop$" {print $2}')

  if [ -z "$desktop_files" ]; then
    echo "ERROR: no /usr/share/applications/*.desktop file found in package $pkg"
    echo "       This means the export list would silently miss this app."
    echo "       Investigate: pacman -Ql $pkg"
    exit 1
  fi

  for d in $desktop_files; do
    base=$(basename "$d" .desktop)
    echo "  found: $base"
    echo "$base" >> "$EXPORT_LIST_TMP"
    apply_wayland_flags "$d"
  done
done

# Dedupe and write final list
sort -u "$EXPORT_LIST_TMP" > /etc/distrobox-export.list
rm -f "$EXPORT_LIST_TMP"

# Assertion gate: every line in the list must resolve to a real .desktop
echo "── asserting /etc/distrobox-export.list entries resolve ──"
while IFS= read -r app; do
  [ -z "$app" ] && continue
  if [ ! -f "/usr/share/applications/${app}.desktop" ]; then
    echo "ASSERT FAIL: /usr/share/applications/${app}.desktop missing for list entry '$app'"
    exit 1
  fi
  echo "  ok: $app"
done < /etc/distrobox-export.list

echo "── final /etc/distrobox-export.list ──"
cat /etc/distrobox-export.list

# ─── Cleanup ────────────────────────────────────────────────────────────────
sudo -u builder yay -Sc --noconfirm
sudo -u builder yay -Scc --noconfirm
rm -rf /home/builder/.cache/yay
pacman -Sc --noconfirm
pacman -Scc --noconfirm
