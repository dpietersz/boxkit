# Quick Start Guide - Daily Driver Toolboxes

## What Was Created

Two custom distrobox/toolbox images for your daily development workflow:

### 1. **daily-driver-fedora** 🔴
Fedora-based container with:
- **GUI Apps**: Zed, Zen Browser, Vivaldi, Qutebrowser, Beekeeper Studio, Cursor, Bruno, Browserpass
- **Essential Tools**: git, pass, zsh, ffmpeg, build tools
- **CLI Tools**: Managed via chezmoi + mise from your dotfiles

### 2. **daily-driver-arch** 🔵
Arch-based container with:
- **GUI Apps**: Obsidian, AnyType, Polypane, Microsoft Storage Explorer (from AUR)
- **Essential Tools**: git, pass, zsh, ffmpeg, build tools
- **CLI Tools**: Managed via chezmoi + mise from your dotfiles

## Building the Images

### Option 1: GitHub Actions (Automatic)
Push your changes to GitHub, and the workflow will automatically build and push images to GHCR.

### Option 2: Local Build (Manual)
```bash
# Build Fedora image
podman build -f ContainerFiles/daily-driver-fedora -t daily-driver-fedora:latest

# Build Arch image
podman build -f ContainerFiles/daily-driver-arch -t daily-driver-arch:latest
```

## Using the Containers

### Create Fedora container:
```bash
distrobox create -i daily-driver-fedora:latest -n daily-driver-fedora
distrobox enter daily-driver-fedora
```

### Create Arch container:
```bash
distrobox create -i daily-driver-arch:latest -n daily-driver-arch
distrobox enter daily-driver-arch
```

## Essential Tools (Pre-installed in Containers)

| Tool | Purpose |
|------|---------|
| `git` | Version control |
| `pass` | Password manager |
| `zsh` | Shell |
| `ffmpeg` | Video/audio processing |
| Build tools | gcc, make, pkg-config (for compiling from source) |

## CLI Tools (Managed via Chezmoi + Mise)

Your dotfiles repository manages all other CLI tools via mise:
- age, bat, btop, chezmoi, doggo, fd, fzf, lazydocker, lazygit, eza, neovim, node, ripgrep, starship, yazi, zellij, zoxide, opencode, python, uv, and more

## Setting Up Your Dotfiles

After creating a container, apply your dotfiles to set up all CLI tools:

```bash
# Enter the container
distrobox enter daily-driver-fedora

# Clone and apply your dotfiles
git clone https://github.com/dpietersz/dotfiles.git ~/.local/share/chezmoi
chezmoi apply

# Verify tools are installed
python --version
node --version
neovim --version
```

This will install all tools configured in your mise `config.toml` with their pinned versions.

## Customization

### Add more system packages to Fedora:
Edit `packages/daily-driver-fedora.packages` and add package names (one per line).

### Add more system packages to Arch:
Edit `packages/daily-driver-arch.packages` and add package names (one per line).

### Add more GUI apps to Arch:
Edit `scripts/daily-driver-arch.sh` and add `yay -S --noconfirm <package-name>` lines.

### Add more GUI apps to Fedora:
Edit `scripts/daily-driver-fedora.sh` and add COPR repos or official repos as needed.

### Manage CLI tool versions:
Edit your dotfiles repository's mise `config.toml` to add/update tool versions. Then run `chezmoi apply` in the container.

## File Locations

- **Fedora ContainerFile**: `ContainerFiles/daily-driver-fedora`
- **Arch ContainerFile**: `ContainerFiles/daily-driver-arch`
- **Fedora packages**: `packages/daily-driver-fedora.packages`
- **Arch packages**: `packages/daily-driver-arch.packages`
- **Fedora setup script**: `scripts/daily-driver-fedora.sh`
- **Arch setup script**: `scripts/daily-driver-arch.sh`
- **GitHub workflow**: `.github/workflows/build-boxkit.yml`
- **Your dotfiles**: https://github.com/dpietersz/dotfiles (manages CLI tools via mise)

## Next Steps

1. **Customize**: Edit the package lists and scripts to add/remove tools as needed
2. **Build**: Run `podman build` locally or push to GitHub for automatic builds
3. **Test**: Create containers and verify all tools work as expected
4. **Deploy**: Use the images with distrobox/toolbox on your system

## Troubleshooting

### Container won't start
- Ensure podman/docker is running
- Check image exists: `podman images | grep daily-driver`

### Missing packages
- Add to the appropriate `.packages` file
- Rebuild the image

### Version conflicts
- Update `.mise.toml` with desired versions
- Rebuild the image

## Documentation

For detailed information, see:
- `DAILY_DRIVER_SETUP.md` - Complete setup documentation
- `README.md` - Original boxkit documentation

