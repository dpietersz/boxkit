# boxkit

## What is boxkit ?

small test

boxkit is a set of GitHub actions and skeleton files to build custom toolbox and distrobox images. Basically, clone this repo, make any changes you need, and then generate your custom images.

Note that boxkit can be used independently of Fedora or uBlue OS.
boxkit requires you atleast understand the basics of [ContainerFiles](https://www.mankier.com/5/Containerfile) and [shell scripting.](https://www.shellscript.sh/)

## Base images

You can use the Docker/OCI container image of practically any distribution as your base image to build your custom image off of. Note that the base images can also be used directly with distrobox/toolbox without any modifications.

Here is a list of some base images you can use:

- [toolbx Community images](https://github.com/toolbx-images/images)
- [uBlue toolboxes](https://github.com/ublue-os/toolboxes)

Try to derive your custom images from these base images so we can all help maintain them over time, you can't have bling without good stock!

Tag your image with `boxkit` to share with others!

## How to use boxkit

### How everything is organized

- The ContainerFiles for the custom images are stored in the `ContainerFiles/` folder.
- The setup scripts for the custom images (if needed) are stored in the `scripts/` folder.
- The package lists for the setup scripts (if needed) are stored in the `packages/` folder.
- The Github workflow that generates the images is `.github/workflows/build-boxkit.yml`

### How to make your own images

1. Fork this repo.
2. Add the ContainerFiles for your custom images to the `ContainerFiles/` folder.
3. Add the setup scripts you want to use for your custom images (if needed) to the `scripts/` folder.
4. Add the package list you want to use for your custom images (if needed) to the `packages/` folder.
5. Add the name of the ContainerFiles of your custom images to the following section in `build-boxkit.yml`:

```yaml
jobs:
  strategy:
    matrix:
      containerfile:
      - [your_custom_image_1]
      - [your_custom_image_2]
```

**Note:** 
- You can choose to only generate a single custom image if you want. 
- You can remove the boxkit and fedora-example images provided in the boxkit repo and only generate your own custom images.
- The `scripts/` and `packages/` folders are optional, you can generate your custom images without them, but they are highly recommended to use.
- The name of your custom image and ContainerFile **MUST** be the same. <br>

  e.g. If you want to create a custom image named *appbox-debian*, the corresponding ContainerFile must be named `appbox-debian` and must be stored inside the `ContainerFiles/` folder.
- The URL for the generated images will be `ghcr.io/<username>/<image_name>` by default.

### Signing your images
Although optional, it is **Highly recommended** you use container signing for your images.
To sign your images, follow the steps below:

1. [Install `cosign`.](https://docs.sigstore.dev/cosign/system_config/installation/)
2. Generate cosign keypairs. <br>
   When it asks you to enter a password, **DONOT ENTER A PASSWORD,** Just press enter.

   ```bash
   cosign generate-key-pair
   ```

   This will create two files named `cosign.pub` and `cosign.key`, which are your public and private keys, respectively.
3. Go to the repository settings of your forked boxkit github repo. (**NOT your GitHub/Account settings**)
   - Go to *Security* > *Secrets and variables* > *Actions*
   - Click on *New repository secret*
   - Create a new secret named `SIGNING_SECRET`
   - Copy the content inside your `cosign.key` file to the textbox that appears when you create the `SIGNING_SECRET` repository secret.
   - Alternatively, you can use GitHub's CLI client.
     ```bash
     gh secret set SIGNING_SECRET < cosign.key
     ```

   **DONOT SHARE YOUR `cosign.key` FILE OR `SIGNING_SECRET` PUBLICLY, STORE THE `cosign.key` FILE SOMEWHERE SECURE AND DONOT INCLUDE IT IN YOUR GIT REPOSITORY.**

4. Delete the `cosign.pub` key that exists on the repository's root folder and copy the `cosign.pub` file you created to the repository's root folder.

Congratulations, you have successfully enabled container signing for all your custom images.

## Available Toolboxes

This repository ships two CI-published toolbox images (pulled from GHCR) plus one **local-build-only** image. See `QUICK_START.md` for usage, NVIDIA setup, and the `/etc/distrobox-export.list` contract.

| Image | Base | Delivery | Description |
|-------|------|----------|-------------|
| `udx-toolbox` | Arch | GHCR (CI) | Daily-driver GUI apps: Storage Explorer, Obsidian, Legcord, Polypane, Bruno, LibreOffice, darktable. (LocalSend lives in `ubuntu-gui-toolbox`; Anytype + Ferdium removed 2026-07-13.) Wayland/niri-ready, NVIDIA-compatible via `distrobox create --nvidia`. |
| `playwright-toolbox` | Ubuntu | GHCR (CI) | Playwright with Chromium, Firefox, WebKit for E2E testing. |
| `resolve-toolbox` | Fedora | **Local build** | DaVinci Resolve. NVIDIA-only. Fedora deps image built on your machine by `scripts/provision-resolve.sh`; Resolve itself is installed into the box at provision time from your license-walled installer (never in the image). See [resolve-toolbox (DaVinci Resolve)](#resolve-toolbox-davinci-resolve) below. |

## Using the custom images

We use the default boxkit image as an example to show you how to create a distrobox/toolbox container using a custom image.

If you use distrobox:

    distrobox create -i ghcr.io/ublue-os/boxkit -n boxkit
    distrobox enter boxkit
    
If you use toolbox:

    toolbox create -i ghcr.io/ublue-os/boxkit -c boxkit
    toolbox enter boxkit

**NOTE:**
- You can use `chezmoi` to pull down your dotfiles and set up git sync.
- It is recommended to use the [Ptyxis](https://flathub.org/apps/app.devsuite.Ptyxis) terminal, which provides seamless integration with various podman/distrobox/toolbx containers.

## Playwright Toolbox

The `playwright-toolbox` provides a complete Playwright testing environment with all browsers pre-installed. This is designed for Bluefin/Fedora Atomic users who want to run Playwright tests from their terminal as if Playwright was installed natively.

### Installation

```bash
# Create the distrobox
distrobox create -i ghcr.io/pietersz/playwright-toolbox -n playwright

# Enter the distrobox and run the one-time setup
distrobox enter playwright -- setup-host-integration
```

That's it! The `setup-host-integration` script exports the Playwright commands to `~/.local/bin` on your host.

### Usage

After setup, you can use Playwright directly from your host terminal:

```bash
# Check version
playwright --version

# Take a screenshot
playwright screenshot https://example.com screenshot.png

# Generate test code with browser recorder
playwright codegen https://your-app.com

# Run tests in a project directory
cd your-project
playwright test
```

### Available Commands

| Command | Description |
|---------|-------------|
| `playwright` | General Playwright CLI (install, test, codegen, etc.) |
| `playwright-test` | Shortcut for `playwright test` |
| `playwright-codegen` | Shortcut for `playwright codegen` |

### What's Included

- **Node.js 22.x** (LTS)
- **Playwright** (latest)
- **Pre-installed browsers:**
  - Chromium
  - Firefox  
  - WebKit (Safari engine)
- All system dependencies for headed and headless browser testing

### Custom Export Path

By default, commands are exported to `~/.local/bin`. To use a different path:

```bash
distrobox enter playwright -- setup-host-integration /path/to/your/bin
```

### Troubleshooting

**Commands not found after setup?**

Make sure `~/.local/bin` is in your PATH. Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Browser fails to launch?**

The container automatically shares your display. If you encounter issues:

```bash
# For X11
echo $DISPLAY  # Should show :0 or similar

# For Wayland (Bluefin default)
ls $XDG_RUNTIME_DIR/wayland-*  # Should show wayland socket
``` 

## resolve-toolbox (DaVinci Resolve)

`resolve-toolbox` runs **DaVinci Resolve** in a **Fedora** distrobox (base and fix set adapted from the proven [zelikos/davincibox](https://github.com/zelikos/davincibox)). Fedora is deliberate: Resolve's bundled Qt/libraries crash on Arch's newer system libraries (`SIGSEGV` in `libQt5Core`), whereas Fedora is close to Blackmagic's supported RHEL/Rocky target and works.

The split is: the **image is Fedora + Resolve's runtime dependencies only — no Resolve, no licensed content** (so it never needs to be a registration-walled or non-redistributable image). **DaVinci Resolve itself is installed into the container at provision time** by `setup-resolve` (shipped in the image) from your local installer. A guided provisioner (`scripts/provision-resolve.sh`) drives the whole thing — build image → create box → install Resolve — pausing only at the steps only you can do (downloading the installer, activating Studio). It is idempotent — safe to re-run.

It is **built locally, not in CI** (kept next to the provision flow). Do not add it to `build-containers.yml` / `cleanup-ghcr.yml` / the release flow without also wiring a provision path.

### Requirements

- **NVIDIA GPU.** Resolve on Linux effectively requires a supported GPU; the provisioner refuses to run on a non-NVIDIA host (i.e. only the P14s, not the T580).
- **Resolve Studio (recommended).** The free version on Linux **cannot decode H.264/H.265** — so consumer camera/phone footage won't import without transcoding to DNxHR/ProRes first. Studio (~US$295, one-time, perpetual, no subscription) adds H.264/H.265 decode. Buy the download/activation-key version online from a Blackmagic-authorized reseller. Activation persists in `$HOME` (mounted), so it survives image rebuilds.
- **Wayland is handled automatically.** Resolve is X11-only; the `davinci-resolve` launcher wrapper forces `QT_QPA_PLATFORM=xcb` so it runs through XWayland (works on niri/Hyprland/GNOME-Wayland). Verified on niri 26.04, including UI dragging.
- **VRAM matters.** On a 4 GB card (e.g. RTX 500 Ada) Resolve will hit "GPU memory is full" on 4K timelines. Edit at a **1080p timeline + Half/Quarter proxy resolution**, generate **Optimized Media** for 4K clips, and close GPU-hungry browsers while editing. These are Resolve Preferences/Project settings (stored in `$HOME`), so they persist across rebuilds.
- **~15–20 GB free disk** for the Fedora image plus the Resolve install.

### Installation

```bash
# 1. Have the boxkit repo checked out (a fresh machine needs this first):
git clone https://github.com/dpietersz/boxkit ~/dev/Projects/boxkit

# 2. Run the guided provisioner (Studio path is the default):
~/dev/Projects/boxkit/scripts/provision-resolve.sh
```

It will, in order: preflight (podman/distrobox/NVIDIA) → **wait for you to download the Resolve `.zip`/`.run`** into `~/Sync/resolve` (or `~/Downloads`; opens the download page for you) → build the Fedora deps image → create the `resolve-toolbox` distrobox with `--nvidia` → **install Resolve into the box** (extract + headless install + patchelf fixes) → export it to your host launcher → print next-steps (incl. Studio activation + the 4 GB VRAM proxy tips).

The installer is read straight from your installer dir at provision time (it's mounted into the box via `$HOME`) — it **never enters the image or the repo**. Keep the `.zip` in a synced folder (e.g. Syncthing) and a reinstall just re-runs the provisioner with no re-download.

### Updating / rebuilding

```bash
# New Resolve installer (upgrade): drop the new .zip in your installer dir, then
~/dev/Projects/boxkit/scripts/provision-resolve.sh --reinstall
# Dependency/image change (rare): rebuild the image, box, and reinstall Resolve
~/dev/Projects/boxkit/scripts/provision-resolve.sh --rebuild --recreate --reinstall
```

### Codec note for this setup

All three of the reference cameras produce H.264/HEVC — **iPhone 13 Mini** (HEVC/Dolby Vision), **Insta360 Go 3S** (H.264/HEVC), **Panasonic Lumix GX80** (H.264). None output ProRes/DNxHD natively, so **Studio is effectively required** for a transcode-free workflow.

> **Prior art:** [zelikos/davincibox](https://github.com/zelikos/davincibox) is a well-known boxkit-style Resolve container worth consulting if the AUR install path needs adjustment.

## Custom images built with boxkit

Here is a list of some awesome custom images built using boxkit.

- [DaVinci Box](https://github.com/zelikos/davincibox) - Container for DaVinci Resolve installation and runtime dependencies on Linux.
- [obs-studio-portable](https://github.com/ublue-os/obs-studio-portable) - OCI container image of OBS Studio that bundles a curated collection of 3rd party plugins.
- [bazzite-arch](https://github.com/ublue-os/bazzite-arch) - A ready-to-game Arch Linux based OCI designed for use exclusively in distrobox.

## Verification

These images are signed with sigstore's [cosign](https://docs.sigstore.dev/quickstart/quickstart-cosign/). You can verify the signature by downloading the `cosign.pub` key from this repository and running the following command:

    cosign verify --key cosign.pub ghcr.io/dpietersz/udx-toolbox
    cosign verify --key cosign.pub ghcr.io/dpietersz/playwright-toolbox
    
If you're forking this repo you should [read the docs](https://docs.github.com/en/actions/security-guides/encrypted-secrets) on keeping secrets in github. You need to [generate a new keypair](https://docs.sigstore.dev/cosign/key_management/signing_with_self-managed_keys/) with cosign. The public key can be in your public repo (your users need it to check the signatures), and you can paste the private key in Settings -> Secrets -> Actions.

![Alt](https://repobeats.axiom.co/api/embed/7c5f037d792c6deb1946e5bc040f64a0fc8abeab.svg "Repobeats analytics image")
# Test release workflow
# Test tag trigger workflow
# Test v1.4.4
# Final test
# Test PAT workflow
# Performance optimization

