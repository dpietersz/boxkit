# Quick Start

This repo builds two container images for use with `distrobox` on Bluefin + niri:

| Image | Base | Purpose |
|-------|------|---------|
| `udx-toolbox` | Arch (toolbx) | Daily-driver GUI apps: Storage Explorer, Obsidian, Legcord, Polypane, Bruno, LibreOffice, darktable |
| `ubuntu-gui-toolbox` | Ubuntu 24.04 (pinned) | LocalSend — needs an older glibc than rolling Arch provides |
| `playwright-toolbox` | Ubuntu (toolbx) | Playwright E2E testing with Chromium / Firefox / WebKit |

Both are published to GHCR at `ghcr.io/<your-gh-user>/<image>:latest`.

---

## Prerequisites

- Bluefin (or any uBlue / Fedora Atomic variant) on the host
- `distrobox` ≥ 1.7
- `podman` (default on Bluefin)
- niri or any Wayland compositor (XWayland fallback also works, but the apps are tuned for native Wayland)
- For the NVIDIA laptop: a working host NVIDIA driver. `nvidia-smi` must succeed on the host before distrobox can pass it through.

---

## Creating udx-toolbox

### On the T580 (Intel graphics)

```bash
distrobox create -i ghcr.io/<your-gh-user>/udx-toolbox:latest -n udx
distrobox enter udx
```

That's it. Intel graphics work out of the box — no host-side flags required.

### On the P14s Gen 5 (NVIDIA RTX)

```bash
distrobox create -i ghcr.io/<your-gh-user>/udx-toolbox:latest -n udx --nvidia
distrobox enter udx
```

The `--nvidia` flag tells distrobox to mount the host's NVIDIA driver libraries (`libcuda`, `libGL`, `libEGL`, `libnvidia-*`) into the container at create time. **The image itself is identical on both laptops.** All the NVIDIA work happens host-side.

Verify NVIDIA passthrough is live from inside the container:

```bash
# Inside the container
nvidia-smi               # should list the RTX card
glxinfo -B | grep -i renderer   # should mention NVIDIA, not "llvmpipe"
```

If `nvidia-smi` doesn't work inside the container but works on the host:

1. Confirm the host driver is loaded: `lsmod | grep nvidia` on the host.
2. Re-create the container with `--nvidia`: `distrobox rm udx && distrobox create -i ... -n udx --nvidia`. The flag cannot be added to an existing container.
3. Check distrobox version: `distrobox --version` — `--nvidia` requires ≥ 1.5.

### What we explicitly do NOT do for NVIDIA

We do not bake NVIDIA-specific Electron flags (VA-API video decode etc.) into the image. Reason: the third-party NVIDIA VA-API shim (`libva-nvidia-driver`) is brittle and the apps in udx-toolbox don't decode meaningful video — the practical benefit is near zero and the crash risk on the P14s is non-zero. NVIDIA OpenGL/Vulkan compositing already works through the driver-lib passthrough. If you ever want hardware video decode for a specific app later, patch its `.desktop` file inside the container; don't change the image.

---

## Creating playwright-toolbox

```bash
distrobox create -i ghcr.io/<your-gh-user>/playwright-toolbox:latest -n playwright
distrobox enter playwright -- setup-host-integration
```

The `setup-host-integration` script exports `playwright`, `playwright-test`, and `playwright-codegen` to `~/.local/bin` on the host. After that you can run `playwright test` from any project on the host as if Playwright were installed natively.

NVIDIA is not relevant here — Playwright drives browsers headlessly.

---

## `/etc/distrobox-export.list` — how GUI apps reach the host menu

This list is the contract between this repo and your dotfiles' distrobox `init_hooks`. Once you understand it, the rest of the GUI integration is trivial. Once it drifts, apps silently disappear from your host menu — which has happened before, so this chapter exists.

### What it is

`/etc/distrobox-export.list` is a plain-text file inside the udx-toolbox container. Each non-empty, non-comment line is a `.desktop` file basename (no `.desktop` suffix, no path) that lives at `/usr/share/applications/<name>.desktop` inside the container.

Your dotfiles' distrobox init_hook reads this file when you enter the container (or shortly after creation) and runs roughly:

```bash
while IFS= read -r app; do
  case "$app" in ''|\#*) continue ;; esac
  distrobox-export --app "$app"
done < /etc/distrobox-export.list
```

`distrobox-export --app <name>` copies the container's `.desktop` to `~/.local/share/applications/` on the host with a tweaked `Exec=` line that calls `distrobox-enter -n udx -- <original-exec>`. So clicking the app from your host menu transparently runs it inside udx-toolbox.

### How udx-toolbox guarantees the list is correct

At build time, `scripts/udx-toolbox.sh` does **not** hard-code basenames. For each installed application package, it asks `pacman -Ql <pkg>` for the real `/usr/share/applications/*.desktop` paths it installed, strips them to basenames, and writes those into the export list.

It then **asserts** every entry resolves — every basename in the list must correspond to an actual file at `/usr/share/applications/<name>.desktop`. If any miss, the build fails. This is the part that prevents the "silently missing apps" problem.

You can inspect the live list inside a running container:

```bash
distrobox enter udx -- cat /etc/distrobox-export.list
```

### When to edit it (and how)

Don't edit `/etc/distrobox-export.list` inside the container — it gets wiped on every image rebuild. To add or remove an app:

1. Edit the `EXPORTED_PACKAGES` line in `scripts/udx-toolbox.sh`.
2. Also edit the install step (add or remove the corresponding `yay_install` / `pacman -S` call).
3. Rebuild the image (locally with `podman build`, or push and let CI build).
4. Re-create or re-enter the container. Run your dotfiles' init_hook (or `distrobox-export --app <name>` manually).

### Why this is fragile in distrobox land (and we work around it)

`.desktop` basenames are upstream-controlled and vary unpredictably:

- Sometimes they match the binary (`obsidian.desktop` → exec `obsidian`).
- Sometimes they use a reverse-DNS ID (`org.qutebrowser.qutebrowser.desktop`).
- Sometimes capitalization is inconsistent (`Polypane.desktop` vs `polypane`).
- Sometimes a package ships several `.desktop` files (a main entry plus URL handlers).

The discover-then-assert pattern in the build script handles all of these — whatever the upstream package installs, that's what the list contains. No human guessing.

---

## Troubleshooting

### Apps don't appear on the host menu

1. Confirm the list is correct: `distrobox enter udx -- cat /etc/distrobox-export.list`
2. Confirm your dotfiles' init_hook ran. Run it manually if needed.
3. Confirm host export landed: `ls ~/.local/share/applications/ | grep udx` (distrobox-export adds a suffix to mark container-exported entries).
4. Restart your host's app menu / launcher (niri's app picker re-scans on launch).

### Apps launch but as XWayland instead of native Wayland

The `udx-toolbox.sh` script preemptively patches every Electron app's `.desktop` Exec line with `--ozone-platform-hint=auto` and PipeWire flags. Verify the patch is in place:

```bash
distrobox enter udx -- grep ozone /usr/share/applications/<app>.desktop
```

If the line is missing, the build script's idempotency check skipped it (probably because the app was already patched in a prior run). Inspect manually and add the flags if needed.

To confirm an app is running Wayland-native on the host, click its window and run on the host:

```bash
xprop WM_CLASS   # then click the window
```

A pure-Wayland window often has no XWayland markers. An easier signal: `wayland-info | grep <app>` should list the client.

### NVIDIA passthrough not working

See the "On the P14s Gen 5" section above — `nvidia-smi` inside the container is the canonical test.

### Screen sharing in Legcord shows a black rectangle

Wayland screen capture requires the host's `xdg-desktop-portal` and `xdg-desktop-portal-gnome` (or `-wlr` on niri-like compositors) to be running. This is a host concern, not the image. Verify on the host:

```bash
systemctl --user status xdg-desktop-portal
```

---

## Updating

When new image versions ship:

```bash
distrobox stop udx
podman pull ghcr.io/<your-gh-user>/udx-toolbox:latest
distrobox rm udx
distrobox create -i ghcr.io/<your-gh-user>/udx-toolbox:latest -n udx   # add --nvidia on P14s
```

Your `$HOME` is shared, so all app config persists across recreates.

---

## File map

```
boxkit/
├── ContainerFiles/
│   ├── udx-toolbox
│   └── playwright-toolbox
├── scripts/
│   ├── udx-toolbox.sh
│   ├── playwright-toolbox.sh
│   ├── distrobox-shims.sh
│   └── decommission-ghcr.sh
├── packages/
│   └── toolbox.packages
└── .github/workflows/
    ├── build-containers.yml
    ├── cleanup-ghcr.yml
    ├── release-please.yml
    └── scheduled-release.yml
```
