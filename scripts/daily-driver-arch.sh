#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
pacman -Syu --noconfirm

# Install base packages from package list
grep -v '^#' ./daily-driver-arch.packages | xargs pacman -S --noconfirm

# Install yay (AUR helper)
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# Install GUI applications from AUR
yay -S --noconfirm obsidian-bin
yay -S --noconfirm anytype-bin
yay -S --noconfirm polypane
yay -S --noconfirm storageexplorer

# Clean up
pacman -Sc --noconfirm

