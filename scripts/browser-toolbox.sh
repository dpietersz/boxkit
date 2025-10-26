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
  git clone https://aur.archlinux.org/yay.git && break
  echo "Git clone attempt $i failed, retrying..."
  sleep 2
done
chown -R builder:builder yay
cd yay
sudo -u builder makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# Install browser and web-related applications
sudo -u builder yay -S --noconfirm zen-browser-bin
sudo -u builder yay -S --noconfirm polypane
pacman -S --noconfirm qutebrowser
pacman -S --noconfirm browserpass
pacman -S --noconfirm chromium

# Clean up yay cache and build artifacts
sudo -u builder yay -Sc --noconfirm
sudo -u builder yay -Scc --noconfirm

# Remove yay build cache
rm -rf /home/builder/.cache/yay

# Clean up pacman cache
pacman -Sc --noconfirm
pacman -Scc --noconfirm

