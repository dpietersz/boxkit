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
dnf install -y zed zen-browser beekeeper-studio browserpass || true

# Install Vivaldi from official repository
# Download and install the official Vivaldi RPM
echo "Attempting to download Vivaldi..."
VIVALDI_VERSION=$(curl -s https://downloads.vivaldi.com/stable/ | grep -oP 'vivaldi-stable-\K[0-9.]+' | head -1)
if [ -n "$VIVALDI_VERSION" ]; then
  echo "Found Vivaldi version: $VIVALDI_VERSION"
  curl -L -o /tmp/vivaldi-stable.rpm "https://downloads.vivaldi.com/stable/vivaldi-stable-${VIVALDI_VERSION}.x86_64.rpm" || true
  if [ -f /tmp/vivaldi-stable.rpm ]; then
    dnf install -y /tmp/vivaldi-stable.rpm || true
    rm /tmp/vivaldi-stable.rpm
  fi
else
  echo "Could not determine Vivaldi version, skipping Vivaldi installation"
fi

# Install Cursor IDE from AppImage
echo "Attempting to download Cursor IDE..."
mkdir -p /opt/cursor
if curl -L -o /opt/cursor/Cursor.AppImage https://download.cursor.sh/linux/appImage/x64; then
  chmod +x /opt/cursor/Cursor.AppImage
  # Create symlink for easy access
  ln -sf /opt/cursor/Cursor.AppImage /usr/local/bin/cursor || true
  echo "Cursor IDE installed successfully"
else
  echo "Failed to download Cursor IDE, skipping"
  rm -rf /opt/cursor
fi

# Install Bruno API client from AppImage
echo "Attempting to download Bruno API client..."
mkdir -p /opt/bruno
if curl -L -o /opt/bruno/Bruno.AppImage https://cdn.usebruno.com/downloads/latest/bruno_latest_linux_x64.AppImage; then
  chmod +x /opt/bruno/Bruno.AppImage
  # Create symlink for easy access
  ln -sf /opt/bruno/Bruno.AppImage /usr/local/bin/bruno || true
  echo "Bruno API client installed successfully"
else
  echo "Failed to download Bruno API client, skipping"
  rm -rf /opt/bruno
fi

# Note: browserpass from COPR is pre-configured for common browsers
# The native messaging host is automatically set up during installation
# Users can verify it works by installing the browserpass extension in their browser

# Clean up
dnf clean all

