#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
pacman -Syu --noconfirm

# Clone and run dotfiles setup before installing packages
# This ensures mise and chezmoi are available for the rest of the setup
cd /tmp
git clone https://github.com/dpietersz/dotfiles.git
cd dotfiles
./setup
cd /

# Install base packages from package list
grep -v '^#' ./daily-driver-arch.packages | xargs pacman -S --noconfirm

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

# Install GUI applications
# Use official obsidian package from extra repository
pacman -S --noconfirm obsidian

# Install AUR packages as non-root user
sudo -u builder yay -S --noconfirm anytype-bin
sudo -u builder yay -S --noconfirm polypane
sudo -u builder yay -S --noconfirm storageexplorer

# Clean up
pacman -Sc --noconfirm

