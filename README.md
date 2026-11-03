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

This repository defines four toolbox images for CI publication to GHCR. See `QUICK_START.md` for usage, NVIDIA setup, and the `/etc/distrobox-export.list` contract.

| Image | Base | Delivery | Description |
|-------|------|----------|-------------|
| `udx-toolbox` | Arch | GHCR (CI) | Daily-driver GUI apps: Storage Explorer, Obsidian, Legcord, Polypane, Bruno, LibreOffice, darktable. (LocalSend lives in `ubuntu-gui-toolbox`; Anytype + Ferdium removed 2026-07-13.) Wayland/niri-ready, NVIDIA-compatible via `distrobox create --nvidia`. |
| `playwright-toolbox` | Ubuntu | GHCR (CI) | Playwright with full Chromium, Chromium headless shell, Firefox, and WebKit for E2E testing. |
| `ubuntu-gui-toolbox` | Ubuntu 24.04 | GHCR (CI) | GUI apps whose prebuilt binaries were believed to need a stable glibc rather than rolling Arch — currently LocalSend (pinned 1.18.2). Same `/etc/distrobox-export.list` contract as `udx-toolbox`. The glibc premise did not reproduce on 2026-09-07; see CLAUDE.md. |
| `insta360-toolbox` | Ubuntu 24.04 / Wine 11 (amd64) | GHCR (CI, next release) | Insta360 Studio runtime. Bring the approved official Studio 6.0.5 installer; proprietary binaries and Wine prefixes are never published. |

## Citrix Workspace (local-only)

**Windows alternative:** the persistent `windows-work` KVM/libvirt VM is not a
Boxkit container. Dotfiles owns its launcher and the authoritative
[installation, Windows 11 Pro rebuild, recovery, and removal runbook](https://github.com/dpietersz/dotfiles/blob/main/docs/how-to/windows-work-vm.html)
(local: `~/dotfiles/docs/how-to/windows-work-vm.html`). Removing that VM does not
remove the Linux Citrix setup below; rebuilding this toolbox must not touch the VM.

For basic work desktops/apps, install the official Citrix x86-64 Debian package
inside the existing `ubuntu-gui-toolbox` (Ubuntu 24.04). Citrix is **not included
in published images**. No host package layering or reboot is needed.

1. Download `icaclient-gcc-8_26.04.10.1_amd64.deb` from
   [Citrix](https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html)
   and review/accept its license. The helper pins this version and verifies its
   official SHA-256; a newer package requires updating both pins deliberately.
2. Run on the host as your normal user:
   ```bash
   ./scripts/install-citrix-workspace.sh --accept-license ~/Downloads/icaclient-gcc-8_26.04.10.1_amd64.deb
   ```
3. Open **Citrix Workspace (on ubuntu-gui-toolbox)** from your app launcher, or
   open an `.ica` file downloaded from your work portal. Authenticate yourself.

The helper installs dependencies, exports the app/protocol launchers, registers
`.ica` handling, and uses XWayland plus the host session bus. It omits USB,
App Protection, deviceTRUST and EPA. If your employer requires endpoint checks
or those security components, this basic setup may not qualify; do not bypass
workplace policy. A working launcher does not prove a successful work session.

**Dotfiles lifecycle:** `~/dotfiles` already owns container creation and its
`distrobox-auto-export.sh` init hook. The helper adds Citrix to the local
`/etc/distrobox-export.list`, so restarts retain exports. However, dotfiles may
**recreate** this container when its GHCR image changes, removing local packages.
Keep the installer outside Git and rerun the helper after recreation. With the
verified installer cached as
`~/.cache/citrix-workspace/icaclient_26.04.10.1_amd64.deb`, only
`./scripts/install-citrix-workspace.sh --accept-license` is needed. Never commit
installers, downloaded ICA files, credentials, or Citrix user state.

Validation: `bash -n scripts/install-citrix-workspace.sh` and
`python3 -m unittest discover -s tests -p 'test_citrix_install.py' -v`.

## Insta360 Studio

```bash
# After the next BoxKit release publishes the image; add --nvidia on NVIDIA hosts.
distrobox create --yes --name insta360-toolbox --image ghcr.io/dpietersz/insta360-toolbox:latest
# Supply the exact official 6.0.5 installer recorded in the trial plan.
distrobox enter --name insta360-toolbox -- /usr/local/bin/insta360-studio --install /absolute/path/to/installer.exe
distrobox enter --name insta360-toolbox -- /usr/local/bin/insta360-studio
distrobox enter --name insta360-toolbox -- distrobox-export --app /usr/share/applications/insta360-studio.desktop
```

The installer remains interactive: accept its terms yourself, decline optional QuickLook, and uncheck launch-at-finish. The helper verifies the approved SHA-256 **before execution**, uses Windows 11 / 144 DPI with the proven Qt scaling override, and blocks the optional QuickLook executables (Studio otherwise recreates their autostart). A different Studio download/build is deliberately rejected until reviewed and its checksum updated.

Prefix: `${XDG_DATA_HOME:-$HOME/.local/share}/insta360-studio/prefix`. Media: **`D:\Pictures` → `~/dev/Pictures`**. Create `~/dev` before setup if it does not exist. The prefix survives toolbox recreation; never run this helper as root. Distrobox shares personal files and is not a security sandbox. Close Studio before setup/install or a toolbox update; do not overwrite source footage.

Dotfiles supplies `insta360-toolbox.ini` and a host `insta360-studio` launcher through its existing creation/export flow. **Publish the BoxKit image before applying those dotfiles on a new machine.** Existing `insta360-studio-test` remains independent; no automatic prefix migration/deletion. See [trial and adoption record](Plans/insta360-studio-trial.html) for evidence, rollback and unresolved media/acceleration checks. User reports Studio works; GO 3S export correctness and NVIDIA hardware encoding are not independently certified.

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
  - Full Chromium (headed or headless)
  - Chromium headless shell
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

## Custom images built with boxkit

Here is a list of some awesome custom images built using boxkit.

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

