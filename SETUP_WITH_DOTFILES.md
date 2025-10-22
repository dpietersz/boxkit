# Setting Up Daily Driver Containers with Your Dotfiles

This guide explains how to use the daily-driver containers with your dotfiles repository.

## Overview

The daily-driver containers are intentionally minimal:
- **Pre-installed**: Essential system tools, build tools, and GUI applications
- **Managed by dotfiles**: All CLI tools via chezmoi + mise

This approach keeps containers lightweight while ensuring your entire development environment is reproducible.

## Container Setup

### Fedora Daily Driver
- **Base**: Fedora Toolbox
- **Pre-installed GUI apps**: Zed, Zen Browser, Vivaldi, Qutebrowser, Beekeeper Studio, Cursor, Bruno, Browserpass
- **Pre-installed system tools**: git, pass, zsh, ffmpeg, build tools
- **Managed by dotfiles**: All CLI tools (bat, eza, fzf, ripgrep, neovim, starship, etc.)

### Arch Daily Driver
- **Base**: Arch Linux
- **Pre-installed GUI apps**: Obsidian, AnyType, Polypane, Microsoft Storage Explorer (from AUR)
- **Pre-installed system tools**: git, pass, zsh, ffmpeg, build tools
- **Managed by dotfiles**: All CLI tools (same as Fedora)

## Quick Start

### 1. Build the containers locally

```bash
podman build -f ContainerFiles/daily-driver-fedora -t daily-driver-fedora:latest
podman build -f ContainerFiles/daily-driver-arch -t daily-driver-arch:latest
```

### 2. Create distrobox containers

```bash
# Fedora
distrobox create -i daily-driver-fedora:latest -n daily-driver-fedora

# Arch
distrobox create -i daily-driver-arch:latest -n daily-driver-arch
```

### 3. Enter and set up your dotfiles

```bash
# Enter the container
distrobox enter daily-driver-fedora

# Clone your dotfiles
git clone https://github.com/dpietersz/dotfiles.git ~/.local/share/chezmoi

# Apply your dotfiles (installs all CLI tools via mise)
chezmoi apply

# Verify installation
python --version
node --version
neovim --version
```

## What Gets Installed

### From Container Build
- Essential system packages (git, pass, zsh)
- Build tools (gcc, make, pkg-config, openssl-devel)
- Multimedia (ffmpeg with full codec support)
- GUI applications (Zed, Zen Browser, Vivaldi, etc.)
- GUI dependencies (X11/Wayland libraries)

### From Your Dotfiles (via chezmoi + mise)
When you run `chezmoi apply`, the following tools are installed:
- age, bat, btop, chezmoi, doggo, fd, fzf
- lazydocker, lazygit, eza, neovim, node
- ripgrep, starship, yazi, zellij, zoxide
- opencode, python, uv, and more

### Configuration Files
Your dotfiles also set up:
- Shell configuration (.zshrc, .bashrc, etc.)
- Editor configuration (neovim, helix, etc.)
- Tool configuration (starship, zellij, etc.)
- Application configs (.config/ directory contents)

## Application Configuration

Your `.config/` directory includes configurations for:
- **Editors**: neovim, helix, zed, cursor
- **Shells**: zsh, bash
- **Tools**: starship, zellij, yazi, lazygit, lazydocker
- **Browsers**: firefox, zen-browser, vivaldi, qutebrowser
- **Other apps**: Various application configs

These will be available in the containers after running `chezmoi apply`.

## Workflow

### First Time Setup
```bash
distrobox enter daily-driver-fedora
git clone https://github.com/dpietersz/dotfiles.git ~/.local/share/chezmoi
chezmoi apply
exit
```

### Subsequent Uses
```bash
distrobox enter daily-driver-fedora
# Your environment is ready to use
```

### Updating Dotfiles
If you update your dotfiles:
```bash
distrobox enter daily-driver-fedora
chezmoi update
exit
```

## Customization

### Add System Packages
Edit the appropriate `.packages` file:
- `packages/daily-driver-fedora.packages` (Fedora)
- `packages/daily-driver-arch.packages` (Arch)

Then rebuild the container.

### Add CLI Tools
Edit your dotfiles' mise `config.toml`:
```toml
[tools]
your-new-tool = "latest"
```

Then run `chezmoi apply` in the container.

### Add GUI Applications
Edit the appropriate setup script:
- `scripts/daily-driver-fedora.sh` (Fedora - use dnf/copr)
- `scripts/daily-driver-arch.sh` (Arch - use yay)

Then rebuild the container.

## Benefits of This Approach

✅ **Lightweight containers** - Only essential packages included  
✅ **Reproducible environment** - Dotfiles ensure consistency  
✅ **Easy updates** - Update tools via dotfiles, not container rebuilds  
✅ **Flexible** - Add tools to dotfiles without rebuilding containers  
✅ **Portable** - Same dotfiles work across different systems  
✅ **Version control** - All configurations tracked in git  

## Troubleshooting

### Tools not found after `chezmoi apply`
Make sure mise is properly initialized:
```bash
eval "$(mise activate bash)"
mise install
```

### GUI apps not working
Ensure X11/Wayland forwarding is enabled:
```bash
distrobox create -i daily-driver-fedora:latest -n daily-driver-fedora -- --preserve-fds
```

### Missing dependencies for GUI apps
Check that all GUI dependencies are installed:
```bash
dnf list installed | grep -E "libxcb|libxkbcommon"
```

## References

- **Dotfiles**: https://github.com/dpietersz/dotfiles
- **Chezmoi**: https://www.chezmoi.io/
- **Mise**: https://mise.jq.fn/
- **Distrobox**: https://distrobox.it/

