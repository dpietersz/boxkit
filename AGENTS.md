# Agent Guidelines for boxkit

## Project Overview

boxkit is a framework for building custom toolbox and distrobox container images using GitHub Actions. The codebase uses ContainerFiles (Dockerfile syntax), shell scripts, and GitHub workflows to build and publish OCI-compliant container images to GHCR.

**Current Images**: boxkit, notetaking-toolbox, data-toolbox, browser-toolbox, playwright-toolbox

## Directory Structure

```
boxkit/
├── ContainerFiles/       # Container definitions (Dockerfile format)
│   ├── boxkit            # Alpine-based CLI toolbox
│   ├── browser-toolbox   # Arch-based browser tools
│   ├── data-toolbox      # Arch-based data management
│   ├── notetaking-toolbox # Arch-based notetaking
│   └── playwright-toolbox # Ubuntu-based E2E testing
├── scripts/              # Shell setup scripts (run during build)
│   ├── distrobox-shims.sh # Common: symlinks for host commands
│   └── {image-name}.sh   # Image-specific setup logic
├── packages/             # Package list files
│   ├── boxkit.packages   # Alpine packages (apk)
│   └── toolbox.packages  # Arch packages (pacman)
└── .github/workflows/    # CI/CD pipelines
```

## Build & Test Commands

### Local Testing (REQUIRED before pushing)

```bash
# Build a single image locally
podman build -f ContainerFiles/{name} -t {name}:test .

# Examples:
podman build -f ContainerFiles/boxkit -t boxkit:test .
podman build -f ContainerFiles/playwright-toolbox -t playwright-toolbox:test .

# Test the built image interactively
podman run -it --rm {name}:test /bin/sh

# Validate a script syntax (no execution)
sh -n scripts/{name}.sh
bash -n scripts/{name}.sh  # For bash-specific scripts
```

### No Traditional Tests

This is an infrastructure repo. Validation is done via successful container builds. Always build locally before pushing changes that modify ContainerFiles, scripts, or packages.

### Linting (Manual)

```bash
shellcheck scripts/*.sh              # Check shell script syntax
hadolint ContainerFiles/{name}       # Validate Dockerfile syntax (if installed)
```

## Code Style & Conventions

### General Formatting (.editorconfig)

- **Indentation**: 2 spaces (no tabs)
- **Line endings**: LF (Unix-style)
- **Charset**: UTF-8
- **Final newline**: Required

### Shell Scripts

**Dialect**: Use POSIX `/bin/sh` unless bash features are required.

**Error Handling**: Always use `set -e` for scripts with multiple steps.

**Variable Naming**: UPPERCASE for environment variables, lowercase for locals.

**Retry Pattern** (for network operations):
```bash
for i in 1 2 3; do
  git clone https://aur.archlinux.org/yay.git && break
  echo "Git clone attempt $i failed, retrying..." && sleep 2
done
[ ! -d "yay" ] && echo "Failed after 3 attempts" && exit 1
```

**Package Installation**:
```bash
# Alpine
apk update && apk upgrade && grep -v '^#' ./boxkit.packages | xargs apk add

# Arch
pacman -Syu --noconfirm && grep -v '^#' ./toolbox.packages | xargs pacman -S --noconfirm

# Ubuntu/Debian
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y && apt-get install -y package1 package2
apt-get clean && rm -rf /var/lib/apt/lists/*  # Always cleanup
```

### ContainerFiles

**Naming**: Lowercase with hyphens (e.g., `notetaking-toolbox`). Must match script name.

**Structure Pattern**:
```dockerfile
FROM quay.io/toolbx-images/alpine-toolbox:edge  # or toolbx/arch-toolbox, toolbx/ubuntu-toolbox

LABEL com.github.containers.toolbox="true" \
      usage="This image is meant to be used with the toolbox or distrobox command" \
      summary="Description of what this toolbox provides" \
      maintainer="your-email@example.com"

COPY ../scripts/{name}.sh /
COPY ../scripts/distrobox-shims.sh /
COPY ../packages/{packages-file}.packages /  # If needed

RUN chmod +x {name}.sh distrobox-shims.sh && /{name}.sh
RUN rm /{name}.sh /distrobox-shims.sh /{packages-file}.packages
```

### Package Files

- One package per line, comments with `#`, processed via `grep -v '^#' | xargs`

## Adding a New Image

1. Create `ContainerFiles/{image-name}`
2. Create `scripts/{image-name}.sh` (must call `./distrobox-shims.sh` first)
3. Create `packages/{image-name}.packages` if needed
4. Add `{image-name}` to `matrix.containerfile` in `.github/workflows/build-containers.yml`
5. Add cleanup step in `.github/workflows/cleanup-ghcr.yml`
6. Test locally: `podman build -f ContainerFiles/{image-name} -t {image-name}:test .`

## Release & Deployment

### Commit Message Format (Conventional Commits)

```
feat: add new playwright-toolbox image     # Minor version bump
fix: correct package installation order    # Patch version bump
chore: weekly package update               # Patch version bump
docs: update README                        # Patch version bump
```

### Release Flow

1. **Manual**: Push conventional commit to main -> release-please creates PR -> merge -> tag -> build
2. **Automated**: Weekly Sunday 10:00 UTC via `scheduled-release.yml`

### Workflow Files

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `release-please.yml` | Push to main | Creates release PRs |
| `build-containers.yml` | Version tags (v*) | Builds & publishes images |
| `scheduled-release.yml` | Weekly Sunday 10:00 UTC | Triggers automated releases |
| `cleanup-ghcr.yml` | Weekly Sunday 02:00 UTC | Keeps last 5 image versions |

## Security & Secrets

### Never Commit
- `cosign.key` (private signing key)
- Any credential files or API keys

### Required Secrets (GitHub)
- `SIGNING_SECRET`: Cosign private key for image signing
- `COSIGN_PASSWORD`: Password for cosign key
- `RELEASE_PLEASE_TOKEN`: PAT for release-please (`contents: write`, `pull-requests: write`)

## Common Patterns

### AUR Package Installation (Arch)
```bash
useradd -m -s /bin/bash builder || true
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder
cd /tmp && git clone https://aur.archlinux.org/yay.git
chown -R builder:builder yay && cd yay && sudo -u builder makepkg -si --noconfirm

# Install AUR packages with retry
for i in 1 2 3; do sudo -u builder yay -S --noconfirm package-name && break; sleep 3; done
```

### Creating Wrapper Scripts
```bash
cat > /usr/local/bin/my-command << 'EOF'
#!/bin/sh
export MY_VAR=/some/path
exec actual-command "$@"
EOF
chmod +x /usr/local/bin/my-command
```

### Distrobox Host Integration
All scripts must call `./distrobox-shims.sh` to set up host command passthrough (docker, podman, flatpak, rpm-ostree).
