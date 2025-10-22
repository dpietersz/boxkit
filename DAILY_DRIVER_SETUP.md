# Daily Driver Toolbox Setup

This document describes the custom daily-driver toolboxes created for development and GUI applications.

## Overview

Two custom toolboxes have been created:

1. **daily-driver-fedora** - Fedora-based toolbox with most GUI applications and CLI tools
2. **daily-driver-arch** - Arch-based toolbox with problematic GUI applications from AUR

## Fedora Daily Driver (`daily-driver-fedora`)

### Base Image
- `quay.io/fedora/fedora-toolbox:latest`

### GUI Applications (via dnf/copr)
- **Zed Editor** - Modern code editor (via `che/zed` COPR)
- **Zen Browser** - Privacy-focused browser (via `sneexy/zen-browser` COPR)
- **Vivaldi** - Feature-rich browser (via official Vivaldi repo)
- **Qutebrowser** - Keyboard-driven browser (via dnf)
- **Beekeeper Studio** - Database management tool (via official repo)
- **Cursor Editor** - AI-powered code editor (via `matthaigh27/cursor` COPR)
- **Bruno** - API client (via `owlburst/bruno` COPR)
- **Browserpass** - Password manager integration (via `akahl/browserpass` COPR, configured for Firefox, Vivaldi, and Chromium)

### Essential System Tools
- **git** - Version control
- **pass** - Password manager
- **zsh** - Shell
- **ffmpeg** - Video/audio processing with full codec support (RPM Fusion)
- **wl-clipboard** - Wayland clipboard
- **xclip** - X11 clipboard
- **dbus-x11** - D-Bus X11 support

### CLI Tools (Managed via Chezmoi + Mise)
All other CLI tools are managed through your dotfiles repository using chezmoi and mise:
- age, bat, btop, chezmoi, doggo, fd, fzf, lazydocker, lazygit, eza, neovim, node, ripgrep, starship, yazi, zellij, zoxide, opencode, python, uv, and more

### Build Tools
- **gcc, make, pkg-config, openssl-devel** - Required for compiling tools from source and building AUR packages

### Tool Management
All CLI tools and their versions are managed through your dotfiles repository using:
- **chezmoi** - Dotfiles management
- **mise** - Tool version management (configured in your dotfiles)

## Arch Daily Driver (`daily-driver-arch`)

### Base Image
- `archlinux:latest`

### GUI Applications (via AUR with yay)
- **Obsidian** - Note-taking app (via `obsidian` AUR)
- **AnyType** - All-in-one workspace (via `anytype-electron-bin` AUR)
- **Polypane** - Responsive design tool (via `polypane` AUR)
- **Microsoft Storage Explorer** - Azure storage management (via `microsoft-azure-storage-explorer` AUR)

### CLI Tools
- Same as Fedora (managed via chezmoi + mise from your dotfiles)

### Build Tools & Helpers
- **base-devel** - Includes gcc, make, and other tools needed for compiling AUR packages and tools from source
- **yay** - AUR helper (installed during setup for easy package management)

## Tool Version Management

Tool versions are managed through your dotfiles repository using mise. Your `config.toml` includes:

```toml
[tools]
age = "latest"
bat = "latest"
btop = "latest"
chezmoi = "latest"
doggo = "latest"
fd = "latest"
fzf = "latest"
lazydocker = "latest"
lazygit = "latest"
eza = "latest"
neovim = "0.11.4"
node = "23.11.0"
ripgrep = "latest"
starship = "1.23.0"
yazi = "latest"
zellij = "0.43.1"
zoxide = "latest"
opencode = "latest"
python = "latest"
uv = "latest"
```

When you run `chezmoi apply` inside the container, mise will install all these tools with their pinned versions.

## Building the Images

The GitHub Actions workflow (`build-boxkit.yml`) has been updated to build all three images:

1. `boxkit` - Original Alpine-based toolbox
2. `daily-driver-fedora` - Fedora-based daily driver
3. `daily-driver-arch` - Arch-based daily driver

Images are automatically built and pushed to GHCR on:
- Manual trigger (`workflow_dispatch`)
- Pull requests to `main`
- Pushes to `main`
- Weekly schedule (Tuesdays at 00:00 UTC)

## Using the Toolboxes

### Create a Fedora daily-driver container:
```bash
distrobox create -i ghcr.io/<username>/daily-driver-fedora -n daily-driver-fedora
distrobox enter daily-driver-fedora
```

### Create an Arch daily-driver container:
```bash
distrobox create -i ghcr.io/<username>/daily-driver-arch -n daily-driver-arch
distrobox enter daily-driver-arch
```

## File Structure

```
boxkit/
├── ContainerFiles/
│   ├── daily-driver-fedora
│   ├── daily-driver-arch
│   ├── boxkit
│   └── fedora-example
├── packages/
│   ├── daily-driver-fedora.packages
│   ├── daily-driver-arch.packages
│   ├── boxkit.packages
│   └── fedora-example.packages
├── scripts/
│   ├── daily-driver-fedora.sh
│   ├── daily-driver-arch.sh
│   ├── boxkit.sh
│   ├── fedora-example.sh
│   └── distrobox-shims.sh
├── .mise.toml
└── .github/workflows/
    └── build-boxkit.yml
```

## Browserpass Configuration

The Fedora container automatically configures browserpass for:
- **Firefox** - Native messaging host configured
- **Vivaldi** - Native messaging host configured
- **Chromium-based browsers** - Native messaging host configured (works with Chromium, Chrome, Edge, Brave, etc.)

To use browserpass:
1. Install the browserpass browser extension from your browser's extension store
2. Set up your password store (using `pass` command)
3. The native messaging host is already configured and ready to use

## Notes

- Both toolboxes include distrobox shims for seamless host command access
- FFmpeg on Fedora includes full codec support via RPM Fusion
- All CLI tools are managed via your dotfiles (chezmoi + mise)
- GUI applications are optimized for each distribution's package ecosystem
- Browserpass is pre-configured for all major browsers in the Fedora container

