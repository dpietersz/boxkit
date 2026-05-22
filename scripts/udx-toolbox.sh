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

# ─── storageexplorer host-export workaround ─────────────────────────────────
# distrobox-export --app <name> uses a CASE-SENSITIVE grep against Exec= and
# Name= in each .desktop file to find the entry. The storageexplorer AUR
# package installs:
#   Exec=env DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 StorageExplorer ...
#   Name=Microsoft Azure Storage Explorer
# Neither line contains the literal "storageexplorer" (lowercase), so
# `distrobox-export --app storageexplorer` — what dotfiles' init_hook calls
# based on the .desktop *filename* — fails with "cannot find any desktop
# files". The other 7 apps work because their binary basename is already
# lowercase and appears in Exec=.
#
# Fix: add a lowercase symlink so `env ... storageexplorer` resolves to the
# real binary, then rewrite the Exec= line below to use that lowercase
# binary. The .desktop now contains the literal "storageexplorer", matching
# distrobox-export's grep. Functionality is unchanged.
ln -sf /opt/StorageExplorer/StorageExplorer /usr/bin/storageexplorer
# Only rewrite the binary token on the Exec= line — Path= and Icon= still
# need the real /opt/StorageExplorer (mixed case) filesystem path.
sed -i -E '/^Exec=/ s/( )StorageExplorer( |$)/\1storageexplorer\2/' /usr/share/applications/storageexplorer.desktop

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

  # Insert flags as the LAST positional args to the actual binary, i.e. just
  # before any XDG field code (%f %F %u %U %c %i %k), or appended to the end
  # if no field code is present. This is wrapper-agnostic: works for direct
  # binary Exec lines AND for env/sh/bash-prefixed Exec lines where the first
  # token is a wrapper, not the binary we want to flag.
  #
  # Wrong pattern (what we used to do): treat the first whitespace-separated
  # token as the binary and insert flags right after it. That broke
  # `Exec=env VAR=val realbinary` because `env` got the flags instead of
  # `realbinary`, and env doesn't understand --ozone-platform-hint.
  if grep -qE "^Exec=.*[[:space:]]+%[fFuUcik]" "$desktop_path"; then
    # Field code present — insert flags right before it
    sed -i -E "s|^(Exec=.*[^[:space:]])([[:space:]]+%[fFuUcik])|\1 ${WAYLAND_FLAGS}\2|" "$desktop_path"
  else
    # No field code — append flags at end of Exec line
    sed -i -E "s|^(Exec=.*[^[:space:]])[[:space:]]*\$|\1 ${WAYLAND_FLAGS}|" "$desktop_path"
  fi

  # Post-patch sanity: the first token after Exec= must NOT be one of our
  # flags. If it is, the sed didn't match anything sensible and the entry
  # is corrupted — fail loudly so the build halts.
  first_token=$(awk -F= '/^Exec=/{print $2; exit}' "$desktop_path" | awk '{print $1}')
  case "$first_token" in
    --*) echo "ASSERT FAIL: patched Exec= starts with a flag ($first_token) in $desktop_path"; return 1 ;;
  esac

  echo "INFO: patched $desktop_path"
}

# ─── Host environment variable injector ────────────────────────────────────
# distrobox init=true shadows the host dbus session bus inside the container.
# Apps that need gnome-keyring (org.freedesktop.secrets) — every Chromium and
# Electron app storing passwords/tokens — must have DBUS_SESSION_BUS_ADDRESS
# pointing at the host bus via /run/host/run/user/1000/bus.
#
# Separately, Chromium/Electron's KeyStorageLinux::SelectBackend checks
# XDG_CURRENT_DESKTOP for the substring "GNOME" to decide whether to use
# gnome-keyring. niri alone triggers the plaintext fallback. Setting
# XDG_CURRENT_DESKTOP=niri:GNOME satisfies the check while keeping niri
# as the primary desktop identifier.

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
    # Already has env wrapper — insert our vars right after "env "
    sed -i -E "s|^(Exec=env )(.*)\$|\1${HOST_ENV_VARS} \2|" "$desktop_path"
  else
    # No env wrapper — add one before the command
    sed -i -E "s|^Exec=(.+)\$|Exec=env ${HOST_ENV_VARS} \1|" "$desktop_path"
  fi

  echo "INFO: injected host env vars into $desktop_path"
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
    apply_host_env_vars "$d"
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
