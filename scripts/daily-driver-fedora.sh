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
dnf copr enable -y che/zed
dnf copr enable -y sneexy/zen-browser
dnf copr enable -y matthaigh27/cursor
dnf copr enable -y owlburst/bruno
dnf copr enable -y akahl/browserpass

# Add Vivaldi official repository
dnf config-manager --add-repo https://repo.vivaldi.com/stable/vivaldi-fedora.repo

# Add Beekeeper Studio official repository
curl -o /etc/yum.repos.d/beekeeper-studio.repo https://rpm.beekeeperstudio.io/beekeeper-studio.repo
rpm --import https://rpm.beekeeperstudio.io/beekeeper.key

# Install GUI applications from COPR and official repos
dnf install -y zed
dnf install -y zen-browser
dnf install -y vivaldi-stable
dnf install -y cursor
dnf install -y bruno
dnf install -y beekeeper-studio
dnf install -y browserpass

# Note: browserpass from COPR is pre-configured for common browsers
# The native messaging host is automatically set up during installation
# Users can verify it works by installing the browserpass extension in their browser

# Clean up
dnf clean all

