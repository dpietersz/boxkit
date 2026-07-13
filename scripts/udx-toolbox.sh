#!/bin/sh

set -e

# ─────────────────────────────────────────────────────────────────────────────
# udx-toolbox — unified Arch daily-driver toolbox
#
# Installs:
#   Electron apps   — Azure Storage Explorer, Obsidian, Legcord, Polypane, Bruno.
#                     (LocalSend moved to ubuntu-gui-toolbox — glibc floor.)
#                     (Anytype + Ferdium removed 2026-07-13 — unused.)
#   Native apps     — LibreOffice (fresh + nl pack + hunspell en_us/nl),
#                     darktable (OpenCL-accelerated RAW editor).
#
# Wayland strategy: Electron apps get preemptively patched .desktop files with
# Chromium/Ozone Wayland flags (ozone hint + PipeWire screen capture +
# Wayland window decorations). Native (non-Chromium) apps must NEVER get
# those flags — soffice and friends treat them as filenames and break.
# Hence the ELECTRON_PACKAGES / NATIVE_PACKAGES split below.
# No NVIDIA-specific flags — NVIDIA passthrough is handled by the host at
# `distrobox create --nvidia` time, not by the image.
#
# Export-list strategy: discovers each app's actual installed .desktop
# basename via `pacman -Ql`, writes /etc/distrobox-export.list from the
# discovered names, then asserts every entry resolves. Build fails if any
# expected .desktop is missing — no silent drift.
# ─────────────────────────────────────────────────────────────────────────────

# Symlink distrobox shims (docker, podman, flatpak, etc. → host)
./distrobox-shims.sh

# Update the container and install base packages
pacman -Syu --noconfirm
grep -v '^#' ./toolbox.packages | xargs pacman -S --noconfirm

# ─── AUR bootstrap ──────────────────────────────────────────────────────────
# makepkg refuses to run as root, so we create a builder user with passwordless
# sudo and install yay (AUR helper) under that account.

useradd -m -s /bin/bash builder || true
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder

cd /tmp
for i in 1 2 3; do
  rm -rf yay 2>/dev/null || true
  git clone https://aur.archlinux.org/yay.git && break
  echo "yay clone attempt $i failed, retrying..."
  sleep 2
done
[ -d "yay" ] || { echo "Failed to clone yay after 3 attempts"; exit 1; }

chown -R builder:builder yay
cd yay
sudo -u builder makepkg -si --noconfirm
cd /
rm -rf /tmp/yay

# ─── Application install ────────────────────────────────────────────────────

# yay_install <package> — install one AUR package with 3-retry loop.
yay_install() {
  pkg="$1"
  for i in 1 2 3; do
    if sudo -u builder yay -S --noconfirm "$pkg"; then
      return 0
    fi
    echo "yay -S $pkg attempt $i failed, retrying..."
    sleep 3
  done
  echo "ERROR: failed to install $pkg after 3 attempts"
  return 1
}

# Obsidian: official Arch extra repo (first-class package, preferred over AUR)
pacman -S --noconfirm obsidian

# LibreOffice: official Arch extra repo. `-fresh` is the latest feature branch
# (matches the daily-driver bias of this image). Dutch UI/help + NL+EN_US
# spellcheck dictionaries because Dimitri lives in NL.
pacman -S --noconfirm libreoffice-fresh libreoffice-fresh-nl hunspell-en_us hunspell-nl

# darktable: official Arch extra repo (native GTK RAW editor). `ocl-icd` is the
# vendor-neutral OpenCL ICD loader so darktable can use GPU acceleration when an
# ICD is present; the NVIDIA OpenCL implementation is mounted host-side by
# `distrobox create --nvidia` (falls back to CPU on the Intel T580 / when absent).
pacman -S --noconfirm darktable ocl-icd

# AUR packages
# LocalSend is deliberately NOT installed here — it lives in ubuntu-gui-toolbox.
# The AUR `localsend-bin` repacks upstream's Ubuntu-built Flutter binary, whose
# Dart VM fails to initialise against this image's rolling glibc (2.43): the
# window maps, nothing paints, and stderr stays empty. See the header of
# scripts/ubuntu-gui-toolbox.sh for the full diagnosis. Do not re-add it here.
# Ferdium and Anytype were removed 2026-07-13 (no longer used).
#
# Removing Ferdium also FIXED the CI build. ferdium-bin depended on `electron37`,
# which Arch has since dropped from [extra] (it now ships electron + electron39..43).
# With no repo package to satisfy it, yay fell back to the AUR `electron37`
# PKGBUILD — which builds Electron/Chromium FROM SOURCE, cloning the multi-GB
# chromium-mirror. That is what hung the v2.2.1 build for 1h49m before it failed,
# with no code change in the repo to explain it.
#
# The lesson generalises: an AUR app pinned to an electronNN that has aged out of
# [extra] turns a 9-minute image build into a multi-hour Chromium compile, silently.
# If a build ever starts taking hours, check for a source-built electron first.
# legcord-bin pins electron41, which IS in [extra] — that one is fine.
yay_install storageexplorer
yay_install legcord-bin
yay_install polypane
yay_install bruno-bin

# ─── storageexplorer host-export workaround ─────────────────────────────────
# distrobox-export --app <name> uses a CASE-SENSITIVE grep against Exec= and
# Name= in each .desktop file to find the entry. The storageexplorer AUR
# package installs:
#   Exec=env DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 StorageExplorer ...
#   Name=Microsoft Azure Storage Explorer
# Neither line contains the literal "storageexplorer" (lowercase), so
# `distrobox-export --app storageexplorer` — what dotfiles' init_hook calls
# based on the .desktop *filename* — fails with "cannot find any desktop
# files". The other 7 apps work because their binary basename is already
# lowercase and appears in Exec=.
#
# Fix: add a lowercase symlink so `env ... storageexplorer` resolves to the
# real binary, then rewrite the Exec= line below to use that lowercase
# binary. The .desktop now contains the literal "storageexplorer", matching
# distrobox-export's grep. Functionality is unchanged.
ln -sf /opt/StorageExplorer/StorageExplorer /usr/bin/storageexplorer
# Only rewrite the binary token on the Exec= line — Path= and Icon= still
# need the real /opt/StorageExplorer (mixed case) filesystem path.
sed -i -E '/^Exec=/ s/( )StorageExplorer( |$)/\1storageexplorer\2/' /usr/share/applications/storageexplorer.desktop

# ─── libreoffice host-export workaround ─────────────────────────────────────
# Same case-sensitive-grep trap as storageexplorer. LibreOffice's .desktop
# files have:
#   Exec=...libreoffice --writer %U     (component is a flag, not a hyphenated name)
#   Name=LibreOffice Writer             (space + mixed case)
# Neither contains the literal "libreoffice-writer" (lowercase, hyphenated)
# that `distrobox-export --app libreoffice-writer` greps for. dotfiles' init
# hook calls distrobox-export with the .desktop basename, so every
# libreoffice-* entry fails with "cannot find any desktop files" without
# this workaround.
#
# Fix: per user-facing component, create a wrapper script at
# /usr/bin/libreoffice-<comp> that execs libreoffice with the right flag,
# then rewrite the primary Exec= line in the matching .desktop to invoke
# the wrapper. The literal "libreoffice-<comp>" now appears in Exec=,
# satisfying distrobox-export's grep. Functionality is unchanged.
#
# Components handled: base, calc, draw, impress, math, writer, startcenter.
# libreoffice-xsltfilter is an internal dev tool (XSLT filter editor), not a
# user app — added to EXPORT_SKIP further down so it's omitted from the
# export list rather than wrapped.
for entry in base:--base calc:--calc draw:--draw impress:--impress \
             math:--math writer:--writer startcenter:; do
  lo_name="${entry%%:*}"
  lo_flag="${entry##*:}"
  [ "$lo_flag" = "$lo_name" ] && lo_flag=""  # startcenter form `name:` → empty flag
  lo_wrapper="/usr/bin/libreoffice-${lo_name}"
  lo_desktop="/usr/share/applications/libreoffice-${lo_name}.desktop"

  if [ ! -f "$lo_desktop" ]; then
    echo "ERROR: $lo_desktop missing — libreoffice install incomplete"
    exit 1
  fi

  cat > "$lo_wrapper" <<WRAPPER
#!/bin/sh
exec /usr/bin/libreoffice ${lo_flag} "\$@"
WRAPPER
  chmod +x "$lo_wrapper"

  if [ -n "$lo_flag" ]; then
    # Components with a flag: replace every `libreoffice --<flag>` occurrence
    # (covers both the primary Exec line and any Desktop Action Exec lines)
    # with the wrapper. The wrapper enforces the flag, so dropping it from
    # the Exec is safe.
    sed -i -E "s|libreoffice ${lo_flag}|libreoffice-${lo_name}|g" "$lo_desktop"
  else
    # startcenter: bare `libreoffice <field-code>` invocation. Only rewrite
    # the primary Exec line (matched by the address regex — `libreoffice`
    # followed by whitespace then an XDG field code). The file also has
    # Action Exec lines like `libreoffice --writer` that must remain
    # unchanged; the address regex excludes them.
    sed -i -E "/^Exec=.*libreoffice[[:space:]]+%[fFuUcik]/ s|libreoffice |libreoffice-startcenter |" "$lo_desktop"
  fi

  # Assertion: the literal wrapper name must now appear in Exec= somewhere.
  if ! grep -qE "^Exec=.*libreoffice-${lo_name}" "$lo_desktop"; then
    echo "ASSERT FAIL: libreoffice-${lo_name} not present in any Exec= of $lo_desktop"
    grep '^Exec=' "$lo_desktop"
    exit 1
  fi
  echo "INFO: wrapped libreoffice-${lo_name} (flag='${lo_flag}')"
done

# ─── Wayland flag patcher (preemptive) ──────────────────────────────────────
# Applied to every Electron app's primary .desktop Exec= line so the apps
# run as Wayland-native windows on niri (no XWayland fallback) and can use
# the xdg-desktop-portal + PipeWire pipeline for screen sharing.
#
# Flags chosen:
#   --ozone-platform-hint=auto         picks Wayland when available, X11 else
#   WaylandWindowDecorations           client-side decorations on Wayland
#   WebRTCPipeWireCapturer +
#   --enable-webrtc-pipewire-capturer  screen share via PipeWire (required on
#                                      Wayland; X11 capture is blocked there)
#
# Explicitly NOT included: VA-API hardware video decode flags. The NVIDIA
# VA-API shim (libva-nvidia-driver) is brittle, has known visual glitches,
# and none of these apps decode meaningful video — zero practical benefit
# and meaningful crash risk on the P14s RTX laptop. NVIDIA GPU compositing
# still works via the host driver libs mounted by `distrobox create --nvidia`.
WAYLAND_FLAGS="--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer --enable-webrtc-pipewire-capturer"

apply_wayland_flags() {
  desktop_path="$1"
  [ -f "$desktop_path" ] || { echo "WARN: $desktop_path not found, skipping flag patch"; return 0; }

  # Idempotency: skip if already patched
  if grep -q -- "--ozone-platform-hint=auto" "$desktop_path"; then
    echo "INFO: $desktop_path already patched"
    return 0
  fi

  # Insert flags as the LAST positional args to the actual binary, i.e. just
  # before any XDG field code (%f %F %u %U %c %i %k), or appended to the end
  # if no field code is present. This is wrapper-agnostic: works for direct
  # binary Exec lines AND for env/sh/bash-prefixed Exec lines where the first
  # token is a wrapper, not the binary we want to flag.
  #
  # Wrong pattern (what we used to do): treat the first whitespace-separated
  # token as the binary and insert flags right after it. That broke
  # `Exec=env VAR=val realbinary` because `env` got the flags instead of
  # `realbinary`, and env doesn't understand --ozone-platform-hint.
  if grep -qE "^Exec=.*[[:space:]]+%[fFuUcik]" "$desktop_path"; then
    # Field code present — insert flags right before it
    sed -i -E "s|^(Exec=.*[^[:space:]])([[:space:]]+%[fFuUcik])|\1 ${WAYLAND_FLAGS}\2|" "$desktop_path"
  else
    # No field code — append flags at end of Exec line
    sed -i -E "s|^(Exec=.*[^[:space:]])[[:space:]]*\$|\1 ${WAYLAND_FLAGS}|" "$desktop_path"
  fi

  # Post-patch sanity: the first token after Exec= must NOT be one of our
  # flags. If it is, the sed didn't match anything sensible and the entry
  # is corrupted — fail loudly so the build halts.
  first_token=$(awk -F= '/^Exec=/{print $2; exit}' "$desktop_path" | awk '{print $1}')
  case "$first_token" in
    --*) echo "ASSERT FAIL: patched Exec= starts with a flag ($first_token) in $desktop_path"; return 1 ;;
  esac

  echo "INFO: patched $desktop_path"
}

# ─── Host environment variable injector ────────────────────────────────────
# distrobox init=true shadows the host dbus session bus inside the container.
# Apps that need gnome-keyring (org.freedesktop.secrets) — every Chromium and
# Electron app storing passwords/tokens — must have DBUS_SESSION_BUS_ADDRESS
# pointing at the host bus via /run/host/run/user/1000/bus.
#
# Separately, Chromium/Electron's KeyStorageLinux::SelectBackend checks
# XDG_CURRENT_DESKTOP for the substring "GNOME" to decide whether to use
# gnome-keyring. niri alone triggers the plaintext fallback. Setting
# XDG_CURRENT_DESKTOP=niri:GNOME satisfies the check while keeping niri
# as the primary desktop identifier.

HOST_ENV_VARS="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/host/run/user/1000/bus XDG_CURRENT_DESKTOP=niri:GNOME"

apply_host_env_vars() {
  desktop_path="$1"
  [ -f "$desktop_path" ] || { echo "WARN: $desktop_path not found, skipping env injection"; return 0; }

  # Idempotency: skip if already injected
  if grep -q "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/host/run/user" "$desktop_path"; then
    echo "INFO: $desktop_path already has host env vars"
    return 0
  fi

  # Two shapes to handle:
  #   Exec=cmd args...           → Exec=env DBUS_... XDG_... cmd args...
  #   Exec=env VAR=val cmd ...   → Exec=env DBUS_... XDG_... VAR=val cmd ...
  # New vars go BEFORE any existing env vars so they take precedence.
  if grep -qE "^Exec=env " "$desktop_path"; then
    # Already has env wrapper — insert our vars right after "env "
    sed -i -E "s|^(Exec=env )(.*)\$|\1${HOST_ENV_VARS} \2|" "$desktop_path"
  else
    # No env wrapper — add one before the command
    sed -i -E "s|^Exec=(.+)\$|Exec=env ${HOST_ENV_VARS} \1|" "$desktop_path"
  fi

  echo "INFO: injected host env vars into $desktop_path"
}

# ─── Discover-then-assert export list ───────────────────────────────────────
# For each installed app package, ask pacman for its real .desktop file
# basenames. Write those to /etc/distrobox-export.list. Then assert each
# entry resolves — build fails if any expected app has no .desktop on disk
# (which would mean the host export would silently miss it).
#
# Two categories drive whether Chromium/Ozone Wayland flags get patched in:
#
#   ELECTRON_PACKAGES — Chromium-based apps. .desktop Exec lines get the
#                       --ozone-platform-hint=auto + PipeWire capture flags.
#                       Add new Electron apps here.
#
#   NATIVE_PACKAGES   — Non-Chromium apps (Qt, GTK, etc.) that would BREAK
#                       if those flags were appended. LibreOffice's soffice
#                       would treat them as filenames and the launchers
#                       would error out. Add new native apps here.
#
# BOTH lists get host env-var injection (DBUS bus + XDG_CURRENT_DESKTOP) and
# BOTH feed the same export list + assert gate.

# NOTE: localsend-bin was previously (wrongly) listed in ELECTRON_PACKAGES.
# LocalSend is Flutter/GTK, not Chromium, so the Ozone flags below were never
# valid for it. It now ships from ubuntu-gui-toolbox instead — see above.
# anytype-bin and ferdium-bin removed 2026-07-13 (unused; ferdium also broke CI).
ELECTRON_PACKAGES="obsidian legcord-bin polypane bruno-bin storageexplorer"
NATIVE_PACKAGES="libreoffice-fresh"

# Discovered .desktop basenames in this list are omitted from the export
# list and not patched. Use for internal/dev .desktops a package ships
# that shouldn't reach the host launcher.
EXPORT_SKIP="libreoffice-xsltfilter"

discover_and_register() {
  pkg="$1"
  patch_wayland="$2"  # "yes" → apply_wayland_flags; anything else → skip
  echo "── discovering .desktop files for $pkg (wayland-flags=$patch_wayland) ──"
  desktop_files=$(pacman -Ql "$pkg" 2>/dev/null \
    | awk '$2 ~ "^/usr/share/applications/.+\\.desktop$" {print $2}')

  if [ -z "$desktop_files" ]; then
    echo "ERROR: no /usr/share/applications/*.desktop file found in package $pkg"
    echo "       This means the export list would silently miss this app."
    echo "       Investigate: pacman -Ql $pkg"
    exit 1
  fi

  for d in $desktop_files; do
    base=$(basename "$d" .desktop)
    case " $EXPORT_SKIP " in
      *" $base "*)
        echo "  skip (EXPORT_SKIP): $base"
        continue
        ;;
    esac
    echo "  found: $base"
    echo "$base" >> "$EXPORT_LIST_TMP"
    if [ "$patch_wayland" = "yes" ]; then
      apply_wayland_flags "$d"
    fi
    apply_host_env_vars "$d"
  done
}

EXPORT_LIST_TMP=$(mktemp)
for pkg in $ELECTRON_PACKAGES; do
  discover_and_register "$pkg" "yes"
done
for pkg in $NATIVE_PACKAGES; do
  discover_and_register "$pkg" "no"
done

# ─── darktable export-list registration (reverse-DNS .desktop trap) ─────────
# darktable ships /usr/share/applications/org.darktable.darktable.desktop with
# Name=darktable / Exec=darktable. distrobox-export --app greps Exec=/Name= for
# the export-list entry string (same trap as storageexplorer/libreoffice above);
# the reverse-DNS basename "org.darktable.darktable" appears in NEITHER line, so
# exporting by that basename would silently find nothing on the host. Normalize
# the launcher to darktable.desktop so the list entry is the literal "darktable"
# that Exec=darktable already contains, then register it explicitly (it is not in
# NATIVE_PACKAGES precisely to avoid the auto-discovered reverse-DNS basename).
# Native app → no Wayland/Ozone flags; host env vars injected for parity.
if [ -f /usr/share/applications/org.darktable.darktable.desktop ]; then
  mv /usr/share/applications/org.darktable.darktable.desktop \
     /usr/share/applications/darktable.desktop
fi
if [ ! -f /usr/share/applications/darktable.desktop ]; then
  echo "ERROR: darktable.desktop not found after install — package layout changed"
  exit 1
fi
apply_host_env_vars /usr/share/applications/darktable.desktop
echo darktable >> "$EXPORT_LIST_TMP"

# Dedupe and write final list
sort -u "$EXPORT_LIST_TMP" > /etc/distrobox-export.list
rm -f "$EXPORT_LIST_TMP"

# Assertion gate: every line in the list must resolve to a real .desktop
echo "── asserting /etc/distrobox-export.list entries resolve ──"
while IFS= read -r app; do
  [ -z "$app" ] && continue
  if [ ! -f "/usr/share/applications/${app}.desktop" ]; then
    echo "ASSERT FAIL: /usr/share/applications/${app}.desktop missing for list entry '$app'"
    exit 1
  fi
  echo "  ok: $app"
done < /etc/distrobox-export.list

echo "── final /etc/distrobox-export.list ──"
cat /etc/distrobox-export.list

# ─── Cleanup ────────────────────────────────────────────────────────────────
sudo -u builder yay -Sc --noconfirm
sudo -u builder yay -Scc --noconfirm
rm -rf /home/builder/.cache/yay
pacman -Sc --noconfirm
pacman -Scc --noconfirm
