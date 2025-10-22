#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
pacman -Syu --noconfirm

# Install base packages from package list
grep -v '^#' ./daily-driver-arch.packages | xargs pacman -S --noconfirm

# Create a non-root user for building AUR packages (makepkg requires this)
useradd -m -s /bin/bash builder || true

# Install yay (AUR helper) as non-root user
cd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R builder:builder yay
cd yay
sudo -u builder makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# Install GUI applications from AUR as non-root user
sudo -u builder yay -S --noconfirm obsidian-bin
sudo -u builder yay -S --noconfirm anytype-bin
sudo -u builder yay -S --noconfirm polypane
sudo -u builder yay -S --noconfirm storageexplorer

# Clean up
pacman -Sc --noconfirm

