#!/bin/sh

set -eu

# Distrobox host-command passthrough is part of every BoxKit image's contract.
./distrobox-shims.sh

if [ "$(dpkg --print-architecture)" != "amd64" ]; then
  echo "ERROR: insta360-toolbox is supported only on amd64." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg python3 util-linux

dpkg --add-architecture i386
install -d -m 0755 /etc/apt/keyrings
key_file=/tmp/winehq.key
for i in 1 2 3; do
  rm -f "$key_file"
  curl --fail --location --silent --show-error \
    https://dl.winehq.org/wine-builds/winehq.key -o "$key_file" && break
  if [ "$i" -eq 3 ]; then
    echo "ERROR: failed to download the WineHQ signing key after 3 attempts." >&2
    exit 1
  fi
  echo "WineHQ key download attempt $i failed, retrying..." >&2
  sleep 2
done

# WineHQ publishes this primary fingerprint at https://dl.winehq.org/wine-builds/.
WINEHQ_FINGERPRINT="D43F640145369C51D786DDEA76F1A20FF987672F"
actual_fingerprint=$(gpg --show-keys --with-colons "$key_file" \
  | awk -F: '$1 == "fpr" { print $10; exit }')
if [ "$actual_fingerprint" != "$WINEHQ_FINGERPRINT" ]; then
  echo "ERROR: WineHQ key fingerprint mismatch: $actual_fingerprint" >&2
  exit 1
fi
gpg --dearmor --yes --output /etc/apt/keyrings/winehq-archive.keyring "$key_file"
rm -f "$key_file"
printf '%s\n' \
  "deb [signed-by=/etc/apt/keyrings/winehq-archive.keyring] https://dl.winehq.org/wine-builds/ubuntu/ noble main" \
  > /etc/apt/sources.list.d/winehq-noble.sources.list

apt-get update
WINE_VERSION="11.0.0.0~noble-1"
apt-get install -y \
  "wine-stable=$WINE_VERSION" \
  "wine-stable-amd64=$WINE_VERSION" \
  "wine-stable-i386=$WINE_VERSION" \
  fonts-wine fonts-liberation fonts-noto-core \
  libgl1 libgl1:i386 libglx0 libglx0:i386 \
  libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
  ffmpeg gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  zenity xvfb xauth x11-utils xdotool desktop-file-utils

if [ ! -x /opt/wine-stable/bin/wine ]; then
  echo "ERROR: WineHQ stable Wine was not installed at /opt/wine-stable/bin/wine." >&2
  exit 1
fi
case "$(/opt/wine-stable/bin/wine --version)" in
  wine-11.0*) ;;
  *)
    echo "ERROR: expected Wine 11.0 from /opt/wine-stable/bin/wine." >&2
    exit 1
    ;;
esac

cat > /usr/share/applications/insta360-studio.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Insta360 Studio
Comment=Launch Insta360 Studio through its isolated Wine prefix
Exec=/usr/local/bin/insta360-studio
StartupWMClass=insta360 studio.exe
Icon=video-x-generic
Terminal=false
Categories=AudioVideo;Video;
EOF

desktop-file-validate /usr/share/applications/insta360-studio.desktop
printf '%s\n' insta360-studio > /etc/distrobox-export.list
[ "$(wc -l < /etc/distrobox-export.list)" -eq 1 ]
[ "$(cat /etc/distrobox-export.list)" = "insta360-studio" ]
[ -f /usr/share/applications/insta360-studio.desktop ]

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "insta360-toolbox setup complete"
