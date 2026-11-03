#!/bin/bash
# Run on the HOST, never during a public image build. Citrix remains local-only.
# Download the x86-64 .deb from Citrix after accepting its license:
# https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html
# Pinned to 26.04.10.1; update the version and official SHA-256 together.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || ${1:-} != --accept-license ]]; then
  echo "Usage: $0 --accept-license [path/to/icaclient_26.04.10.1_amd64.deb]" >&2
  echo "--accept-license confirms that you accept Citrix's license for this installation." >&2
  exit 2
fi

version=26.04.10.1
sha256=59323832a7a6966b9a6bf141d72521c068337b390ea1ba2b54325efd0b718572
container=ubuntu-gui-toolbox
package=${2:-$HOME/.cache/citrix-workspace/icaclient_${version}_amd64.deb}
if [[ ! -f "$package" ]]; then
  echo "Installer not found: $package. Download the pinned x86-64 .deb from Citrix." >&2
  exit 1
fi
package=$(realpath -- "$package")
if [[ $(sha256sum -- "$package" | cut -d ' ' -f 1) != "$sha256" ]]; then
  echo "Citrix installer checksum mismatch; refusing installation." >&2
  exit 1
fi
if [[ $(id -u) == 0 || -n ${CONTAINER_ID:-} ]]; then
  echo "Run this helper as your normal user on the host, not inside a container." >&2
  exit 1
fi
for command in distrobox xdg-mime update-desktop-database; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done

# Distrobox provides container-only sudo. No host root, USB or security agents.
distrobox enter -n "$container" --no-tty -- sh -s -- "$package" "$version" "$sha256" <<'CONTAINER'
set -eu
package=$1
version=$2
sha256=$3
. /etc/os-release
[ "$ID" = ubuntu ] && [ "$VERSION_ID" = 24.04 ] || {
  echo "Expected Ubuntu 24.04 container" >&2; exit 1;
}
[ "$(dpkg --print-architecture)" = amd64 ] || exit 1
[ "$(sha256sum -- "$package" | cut -d ' ' -f 1)" = "$sha256" ] || exit 1
[ "$(dpkg-deb -f "$package" Package)" = icaclient ] || exit 1
[ "$(dpkg-deb -f "$package" Version)" = "$version" ] || exit 1
printf '%s\n' \
  'icaclient app_protection/install_app_protection select no' \
  'icaclient devicetrust/install_devicetrust select no' \
  'icaclient epa/install_epa select no' | sudo -n debconf-set-selections
sudo -n apt-get update -qq
sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  "$package" ca-certificates libgtk-3-0t64 libsecret-1-0 libxml2 \
  libwebkit2gtk-4.1-0 libxerces-c3.2t64 libsoup2.4-1 libnotify4 libopengl0 libopenjp2-7

for binary in wfica selfservice AuthManagerDaemon; do
  missing=$(ldd "/opt/Citrix/ICAClient/$binary" | grep 'not found' || true)
  if [ -n "$missing" ]; then
    printf '%s\n' "$binary: $missing" >&2
    exit 1
  fi
done

# Patch in-container entries too, so dotfiles' existing auto-export init hook
# preserves the X11 and host-keyring environment on container restarts.
for app in selfservice wfica citrixapp citrixweb; do
  desktop=/usr/share/applications/$app.desktop
  sudo -n sed -i -E \
    -e "s|^Exec=[[:space:]]*/opt/|Exec=env GDK_BACKEND=x11 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/host/run/user/$(id -u)/bus /opt/|" \
    -e '/^Encoding=/d' \
    -e 's/^Categories=.*/Categories=Network;/' "$desktop"
  if ! grep -qxF "$app" /etc/distrobox-export.list; then
    printf '%s\n' "$app" | sudo -n tee -a /etc/distrobox-export.list >/dev/null
  fi
  distrobox-export --app "$desktop"
done
CONTAINER

applications=${XDG_DATA_HOME:-$HOME/.local/share}/applications
sed -i 's|^StartupWMClass=.*|StartupWMClass=Selfservice|' \
  "$applications/$container-selfservice.desktop"
update-desktop-database "$applications"
xdg-mime default "$container-wfica.desktop" application/x-ica
xdg-mime default "$container-citrixapp.desktop" x-scheme-handler/citrixapp
xdg-mime default "$container-citrixweb.desktop" x-scheme-handler/citrixweb
printf '\nCitrix %s installed. Open Citrix Workspace from your app launcher,\nor open an .ica file downloaded from your work portal.\n' "$version"
printf 'Container recreation removes local packages. Rerun this helper afterward.\n'
