# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`boxkit` is Dimitri's fork of the ublue-os boxkit framework — a set of `ContainerFiles`, shell scripts, and GitHub Actions that build and publish OCI toolbox images to GHCR. Two images ship today:

| Image | Base | Purpose |
|---|---|---|
| `ghcr.io/dpietersz/udx-toolbox` | Arch (`toolbx-images/arch-toolbox`) | Daily-driver GUI apps that have no acceptable Fedora source: Storage Explorer, Obsidian, Anytype, Legcord, Polypane, Bruno, LocalSend, Ferdium. Wayland/niri-tuned. NVIDIA-compatible via `distrobox create --nvidia` (the image is identical on Intel and NVIDIA — passthrough is host-side). |
| `ghcr.io/dpietersz/playwright-toolbox` | Ubuntu (`toolbx-images/ubuntu-toolbox`) | Playwright + Chromium/Firefox/WebKit for E2E testing. `setup-host-integration` exports `playwright*` to `~/.local/bin` on the host. |

This repo is **the GUI-app delivery layer** of a three-repo personal ecosystem. Most "I want app X" requests do not belong here — read the next section before adding anything.

## The three-repo ecosystem (READ THIS FIRST)

`boxkit` is one of three tightly-coupled personal repos. A change here usually implies a change in one of the others, or the change belongs in one of the others instead.

```
┌─────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│   bluefin-udx       │     │     dotfiles         │     │      boxkit          │
│ (~/dev/Projects/    │     │     (~/dotfiles)     │     │    (THIS REPO)       │
│   bluefin-udx)      │     │                      │     │                      │
│                     │     │                      │     │                      │
│ Bootc image         │ ──> │ chezmoi user config  │ ──> │ distrobox toolbox    │
│ System packages     │     │ Per-machine layer    │     │ images for GUI apps  │
│ rpm-ostree layer    │     │ mise / brew / pass   │     │ no Fedora pkg path   │
└─────────────────────┘     └──────────────────────┘     └──────────────────────┘
       ▲                              │                              ▲
       │                              │ chezmoi pulls toolbox        │
       │      provides bootstrap      │ images + runs auto-export    │
       │      (pass, gpg, git, ...)   │ via /etc/distrobox-export.list│
       └──────────────────────────────┴──────────────────────────────┘
                  (toolbox apps appear on host with correct icons)
```

### Division of responsibility

| Layer | Owns | Examples |
|---|---|---|
| **bluefin-udx** | System packages requiring `sudo`/reboot, portal/PAM/polkit/screen-share integration, bootstrap tooling | `kitty`, `niri`, `waybar`, `mate-polkit`, `pass`, `gnupg2`, `git`, `chromium`, `zen-browser`, `zed` |
| **dotfiles** | User-scope `~/.config/`, `mise`/`brew` packages, secrets via `pass`, `distrobox` `.ini` per-box config, **the cron/init-hook that runs `distrobox-auto-export.sh` and consumes `/etc/distrobox-export.list`** | Neovim, starship, language runtimes, niri/waybar config, brew bundles |
| **boxkit (THIS REPO)** | GUI apps with no acceptable Fedora source (no maintained COPR/RPM, and Flatpak/AppImage rejected as primary delivery). Produces `udx-toolbox` + `playwright-toolbox` and — critically — **writes `/etc/distrobox-export.list` inside the image** so dotfiles' init_hook knows what to export. | All `udx-toolbox` apps above; Playwright + browsers |

**Hard rules** (Dimitri's preferences, baked into the architecture):
- **No Flatpak. No AppImage as primary delivery.** If a GUI app has no Fedora RPM, it belongs in `udx-toolbox`.
- **Atomic OS = no `rpm-ostree install` at chezmoi-time.** Things that need `sudo` go in `bluefin-udx`; things that can live as `mise`/`brew`/toolbox go in dotfiles/boxkit.
- **One image, two laptops, zero drift.** Per-machine logic lives in chezmoi templates in dotfiles — never in `bluefin-udx`, never in this repo. The boxkit image is identical on T580 (Intel) and P14s Gen 5 (NVIDIA); the only difference is the `--nvidia` flag at `distrobox create` time.

### The integration handshake

1. **bluefin-udx** boots on the host → provides `pass`, `gpg`, `age`, `ssh`, `git`, `distrobox`, `podman`.
2. **chezmoi apply** in dotfiles runs `.chezmoiscripts/run_after_11-create-toolboxes` → reads `dot_config/distrobox/*.ini.tmpl`, uses `skopeo inspect` to detect ghcr digest bumps, recreates stale boxes.
3. Each box's `init_hooks` runs `distrobox-auto-export.sh` inside the container → reads `/etc/distrobox-export.list` (**this file is written by THIS repo's `scripts/udx-toolbox.sh`**) → calls `distrobox-export --app <name>` for each entry so `.desktop` files + icons surface in the host launcher (niri/wofi).
4. Result: an app baked here appears on the host menu with the correct icon, zero manual export calls.

A request "I want app X" routes as:
- **Needs sudo / reboot / system integration** → `bluefin-udx`
- **Fedora RPM exists OR clean brew/mise package** → dotfiles
- **GUI app with no Fedora RPM (and Flatpak/AppImage rejected)** → here, in `udx-toolbox`, AND add it to the discover-then-assert block in `scripts/udx-toolbox.sh` so it lands in `/etc/distrobox-export.list`

### Cross-repo authoritative docs

- `~/dev/Projects/bluefin-udx/CLAUDE.md`, `RECIPE.md`, `MAINTENANCE.md` — bake doctrine, package manifest, quarterly review
- `~/dotfiles/CLAUDE.md` — chezmoi script ordering, distrobox `.ini` templates, the auto-export init_hook
- `QUICK_START.md` (here) — `--nvidia` semantics, `/etc/distrobox-export.list` contract, the case-sensitive `distrobox-export --app` grep trap
- `AGENTS.md` (here) — ContainerFile / scripts / packages conventions, AUR install pattern, conventional-commits release flow

## Repository layout

```
ContainerFiles/         # One Dockerfile per image — name MUST equal the image name
  udx-toolbox           # FROM arch-toolbox, COPYs scripts/udx-toolbox.sh + packages
  playwright-toolbox    # FROM ubuntu-toolbox
scripts/                # Build-time setup scripts (run inside the image)
  distrobox-shims.sh    # MUST be called first by every image script — sets up host
                        #   command passthrough (docker, podman, flatpak, rpm-ostree)
  udx-toolbox.sh        # Installs pacman + AUR packages, then the discover-then-assert
                        #   block that writes /etc/distrobox-export.list (read by dotfiles)
  playwright-toolbox.sh # Node 22 + playwright install + setup-host-integration shim
  decommission-ghcr.sh  # One-shot: wipe legacy GHCR packages
packages/
  toolbox.packages      # Arch pacman list (# comments stripped, xargs-fed)
.github/workflows/
  build-containers.yml  # Tag-triggered (v*) build + sign + publish to GHCR
  release-please.yml    # Conventional-commits → release PR on main
  scheduled-release.yml # Weekly Sunday 10:00 UTC automated release
  cleanup-ghcr.yml      # Weekly Sunday 02:00 UTC, keeps last 5 versions
cosign.pub              # Public signing key. cosign.key is NEVER committed.
```

## Build & verify locally (do this before pushing)

```bash
# Build a single image
podman build -f ContainerFiles/udx-toolbox -t udx-toolbox:test .
podman build -f ContainerFiles/playwright-toolbox -t playwright-toolbox:test .

# Poke around inside
podman run -it --rm udx-toolbox:test /bin/bash

# Verify the export-list contract for udx-toolbox (this is what dotfiles consumes)
podman run --rm udx-toolbox:test cat /etc/distrobox-export.list

# Shellcheck before commits that touch scripts/
shellcheck scripts/*.sh

# Syntax-only check
sh -n scripts/distrobox-shims.sh
bash -n scripts/udx-toolbox.sh
```

There are no traditional tests — validation is "does the image build, and does `/etc/distrobox-export.list` resolve every entry to a real `.desktop`". `scripts/udx-toolbox.sh` enforces the second at build time (the assert loop on the export list will fail the build if any entry doesn't resolve).

## Release flow

Conventional commits on `main` → release-please opens a PR → merging the PR cuts a tag → `build-containers.yml` fires on the tag → images published to `ghcr.io/dpietersz/{udx,playwright}-toolbox:{latest,vX.Y.Z}` and signed with cosign.

`feat:` = minor bump, `fix:`/`chore:`/`docs:` = patch bump. Weekly automated release covers package refresh even without human commits.

## Adding a new image

1. `ContainerFiles/<name>` (name = image name, lowercase-hyphen)
2. `scripts/<name>.sh` — first line after shebang/`set -e` must be `./distrobox-shims.sh`
3. `packages/<name>.packages` if applicable
4. Add `<name>` to `matrix.containerfile` in `.github/workflows/build-containers.yml`
5. Add cleanup step in `.github/workflows/cleanup-ghcr.yml`
6. If it's a GUI image: write `/etc/distrobox-export.list` in the build script — the dotfiles init_hook depends on this contract
7. `podman build -f ContainerFiles/<name> -t <name>:test .` locally before pushing

## Invariants worth knowing before editing

- `/etc/distrobox-export.list` entries are matched **case-sensitively** by `distrobox-export --app` against `Exec=` and `Name=` in `.desktop` files. The discover-then-assert block in `scripts/udx-toolbox.sh` exists precisely because a silent miss here = app disappears from the host menu. Don't bypass it.
- `distrobox-shims.sh` runs first or host passthrough breaks — every image script calls it.
- AUR installs use the `builder` user + 3-retry loop pattern documented in `AGENTS.md`. Network flakiness is the default assumption.
- The udx-toolbox image is **identical on Intel and NVIDIA hosts**. NVIDIA support is `--nvidia` at create time, not a baked-in variant. Don't add an `udx-toolbox-nvidia` image.
- `cosign.key` is in `SIGNING_SECRET` on GitHub. Never commit it. `cosign.pub` is checked in so users can verify (`cosign verify --key cosign.pub ghcr.io/dpietersz/udx-toolbox`).
