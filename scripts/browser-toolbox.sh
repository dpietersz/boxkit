#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
pacman -Syu --noconfirm

# Install base packages from package list
grep -v '^#' ./toolbox.packages | xargs pacman -S --noconfirm

# Create a non-root user for building AUR packages (makepkg requires this)
useradd -m -s /bin/bash builder || true

# Configure sudoers to allow passwordless sudo for builder user
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder

# Install yay (AUR helper) as non-root user
cd /tmp
for i in 1 2 3; do
  rm -rf yay 2>/dev/null || true
  git clone https://aur.archlinux.org/yay.git && break
  echo "Git clone attempt $i failed, retrying..."
  sleep 2
done

if [ ! -d "yay" ]; then
  echo "Failed to clone yay after 3 attempts"
  exit 1
fi

chown -R builder:builder yay
cd yay
sudo -u builder makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# Install browser and web-related applications
for i in 1 2 3; do
  sudo -u builder yay -S --noconfirm zen-browser-bin && break
  echo "zen-browser-bin attempt $i failed, retrying..."
  sleep 3
done

for i in 1 2 3; do
  sudo -u builder yay -S --noconfirm polypane && break
  echo "polypane attempt $i failed, retrying..."
  sleep 3
done

# Install Microsoft Teams (unofficial Electron client) for meetings + screen sharing
for i in 1 2 3; do
  sudo -u builder yay -S --noconfirm teams-for-linux-bin && break
  echo "teams-for-linux-bin attempt $i failed, retrying..."
  sleep 3
done

# Patch the launcher so Teams runs natively on Wayland and can capture screens
# via the xdg-desktop-portal + PipeWire pipeline (required on Bluefin's Wayland
# session). --ozone-platform-hint=auto must be a CLI flag — the upstream config
# explicitly does not honor it via electronCLIFlags.
for TEAMS_DESKTOP in /usr/share/applications/teams-for-linux.desktop \
                     /usr/share/applications/com.github.IsmaelMartinez.teams_for_linux.desktop; do
  [ -f "$TEAMS_DESKTOP" ] || continue
  sed -i -E 's|^(Exec=.*teams-for-linux)([[:space:]]+%U)?[[:space:]]*$|\1 --ozone-platform-hint=auto --enable-features=WebRTCPipeWireCapturer,WaylandWindowDecorations --enable-webrtc-pipewire-capturer %U|' "$TEAMS_DESKTOP"
done

# Drop a system-wide default config that the launcher wrapper seeds into the
# user's $HOME on first run. screenSharing.lockInhibitionMethod=WakeLockSentinel
# keeps the screen awake during calls without using the legacy Electron API
# that breaks under Wayland. disableGpu=false re-enables hw accel (teams-for-
# linux auto-disables it on Wayland, which makes screen sharing blurry).
mkdir -p /etc/teams-for-linux
cat > /etc/teams-for-linux/config.json.default <<'EOF'
{
  "disableGpu": false,
  "screenSharing": {
    "lockInhibitionMethod": "WakeLockSentinel"
  },
  "wayland": {
    "xwaylandOptimizations": false
  }
}
EOF

# Wrap the binary so the default config is seeded once per user. distrobox
# shares $HOME with the host, so this writes to the host's real config dir and
# persists across container rebuilds. Users can edit the file freely afterwards.
mv /usr/bin/teams-for-linux /usr/bin/teams-for-linux.real
cat > /usr/bin/teams-for-linux <<'EOF'
#!/bin/sh
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/teams-for-linux"
if [ ! -f "$CFG_DIR/config.json" ] && [ -f /etc/teams-for-linux/config.json.default ]; then
  mkdir -p "$CFG_DIR"
  cp /etc/teams-for-linux/config.json.default "$CFG_DIR/config.json"
fi
exec /usr/bin/teams-for-linux.real "$@"
EOF
chmod +x /usr/bin/teams-for-linux

# Install Helium browser manually (bypasses AUR/makepkg overlay filesystem issues)
HELIUM_VERSION="0.12.3.1"
cd /tmp
for i in 1 2 3; do
  curl -LO "https://github.com/imputnet/helium-linux/releases/download/${HELIUM_VERSION}/helium-${HELIUM_VERSION}-x86_64_linux.tar.xz" && break
  echo "Helium download attempt $i failed, retrying..."
  sleep 3
done
tar xf "helium-${HELIUM_VERSION}-x86_64_linux.tar.xz"
mkdir -p /opt/helium-browser-bin
cp --no-preserve=mode,ownership -r "helium-${HELIUM_VERSION}-x86_64_linux/"* /opt/helium-browser-bin/
chmod +x /opt/helium-browser-bin/helium*
ln -sf /opt/helium-browser-bin/helium /usr/local/bin/helium
cp /opt/helium-browser-bin/helium.desktop /usr/share/applications/
rm -rf "/tmp/helium-${HELIUM_VERSION}-x86_64_linux" "/tmp/helium-${HELIUM_VERSION}-x86_64_linux.tar.xz"
cd /

pacman -S --noconfirm qutebrowser
pacman -S --noconfirm browserpass browserpass-chromium
pacman -S --noconfirm chromium

# Declare GUI apps to export to host (consumed by distrobox init_hooks in dotfiles).
# One <basename-of-.desktop> per line; comments with #.
cat > /etc/distrobox-export.list <<'EOF'
zen
chromium
helium
Polypane
org.qutebrowser.qutebrowser
teams-for-linux
EOF

# Clean up yay cache and build artifacts
sudo -u builder yay -Sc --noconfirm
sudo -u builder yay -Scc --noconfirm

# Remove yay build cache
rm -rf /home/builder/.cache/yay

# Clean up pacman cache
pacman -Sc --noconfirm
pacman -Scc --noconfirm

