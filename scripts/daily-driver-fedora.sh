#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
dnf update -y

# Install base packages from package list
grep -v '^#' ./daily-driver-fedora.packages | xargs dnf install -y

# Enable RPM Fusion for multimedia codecs
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Swap ffmpeg-free for ffmpeg with full codec support
dnf swap -y ffmpeg-free ffmpeg --allowerasing || dnf install -y ffmpeg --allowerasing

# Enable COPR repositories for GUI applications
dnf copr enable -y che/zed || true
dnf copr enable -y sneexy/zen-browser || true
dnf copr enable -y akahl/browserpass || true

# Add Beekeeper Studio official repository
curl -o /etc/yum.repos.d/beekeeper-studio.repo https://rpm.beekeeperstudio.io/beekeeper-studio.repo || true
rpm --import https://rpm.beekeeperstudio.io/beekeeper.key || true

# Install GUI applications from COPR and official repos
dnf install -y zed zen-browser beekeeper-studio browserpass chromium qutebrowser || true

# Note: browserpass from COPR is pre-configured for common browsers
# The native messaging host is automatically set up during installation
# Users can verify it works by installing the browserpass extension in their browser

# Clean up
dnf clean all

