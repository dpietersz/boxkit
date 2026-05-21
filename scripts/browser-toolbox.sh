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

# Clean up yay cache and build artifacts
sudo -u builder yay -Sc --noconfirm
sudo -u builder yay -Scc --noconfirm

# Remove yay build cache
rm -rf /home/builder/.cache/yay

# Clean up pacman cache
pacman -Sc --noconfirm
pacman -Scc --noconfirm

