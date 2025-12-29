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

This repository provides several ready-to-use toolbox images:

| Image | Base | Description |
|-------|------|-------------|
| `boxkit` | Alpine | Basic cloud-native terminal experience |
| `browser-toolbox` | Arch | Zen Browser, Chromium, Polypane, qutebrowser |
| `data-toolbox` | Arch | Storage Explorer, Beekeeper Studio, Bruno |
| `notetaking-toolbox` | Arch | Obsidian, Anytype, Legcord |
| `playwright-toolbox` | Ubuntu | Playwright with Chromium, Firefox, WebKit for E2E testing |

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

## Custom images built with boxkit

Here is a list of some awesome custom images built using boxkit.

- [DaVinci Box](https://github.com/zelikos/davincibox) - Container for DaVinci Resolve installation and runtime dependencies on Linux.
- [obs-studio-portable](https://github.com/ublue-os/obs-studio-portable) - OCI container image of OBS Studio that bundles a curated collection of 3rd party plugins.
- [bazzite-arch](https://github.com/ublue-os/bazzite-arch) - A ready-to-game Arch Linux based OCI designed for use exclusively in distrobox.

## Verification

These images are signed with sigstore's [cosign](https://docs.sigstore.dev/quickstart/quickstart-cosign/). You can verify the signature by downloading the `cosign.pub` key from this repository and running the following command:

    cosign verify --key cosign.pub ghcr.io/ublue-os/boxkit
    
If you're forking this repo you should [read the docs](https://docs.github.com/en/actions/security-guides/encrypted-secrets) on keeping secrets in github. You need to [generate a new keypair](https://docs.sigstore.dev/cosign/key_management/signing_with_self-managed_keys/) with cosign. The public key can be in your public repo (your users need it to check the signatures), and you can paste the private key in Settings -> Secrets -> Actions.

![Alt](https://repobeats.axiom.co/api/embed/7c5f037d792c6deb1946e5bc040f64a0fc8abeab.svg "Repobeats analytics image")
# Test release workflow
# Test tag trigger workflow
# Test v1.4.4
# Final test
# Test PAT workflow
# Performance optimization

