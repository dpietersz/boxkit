#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
pacman -Syu --noconfirm

# Install base packages from package list
grep -v '^#' ./data-toolbox.packages | xargs pacman -S --noconfirm

# Create a non-root user for building AUR packages (makepkg requires this)
useradd -m -s /bin/bash builder || true

# Configure sudoers to allow passwordless sudo for builder user
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder

# Install yay (AUR helper) as non-root user
cd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R builder:builder yay
cd yay
sudo -u builder makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# Install data management applications
sudo -u builder yay -S --noconfirm storageexplorer
sudo -u builder yay -S --noconfirm beekeeper-studio-bin
# Install bruno-bin with error handling to avoid debug package conflicts
sudo -u builder yay -S --noconfirm bruno-bin || true

# Clean up yay cache and build artifacts
sudo -u builder yay -Sc --noconfirm
sudo -u builder yay -Scc --noconfirm

# Remove yay build cache
rm -rf /home/builder/.cache/yay

# Clean up pacman cache
pacman -Sc --noconfirm
pacman -Scc --noconfirm

