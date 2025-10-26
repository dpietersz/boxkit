# Agent Guidelines for boxkit

## Project Overview
boxkit is a GitHub Actions and skeleton framework for building custom toolbox and distrobox container images. The codebase uses ContainerFiles (Dockerfile-like syntax), shell scripts, and GitHub workflows.

## Build & Testing
- **Build container images**: Uses Buildah via GitHub Actions (`.github/workflows/build-containers.yml`)
- **Build process**: Triggered on version tags (`v*`); builds four images: boxkit, notetaking-toolbox, data-toolbox, browser-toolbox
- **Local testing**: Build a specific Containerfile with `podman build -f ContainerFiles/{name} -t {name}:test .`
- **No traditional tests**: This is an infrastructure repo; validate changes via container builds
- **Scheduled releases**: Weekly on Sundays at 10:00 UTC (noon Amsterdam time) via `scheduled-release.yml` workflow

## Code Structure
- **ContainerFiles/**: Container definitions (Dockerfile format)
- **scripts/**: Shell setup scripts (sh/bash) that run inside containers during build
- **packages/**: Package list files (one per line, comments with #)
- **.github/workflows/**: CI/CD pipeline definitions
- **Container signing**: Uses cosign; private key stored in SIGNING_SECRET GitHub secret

## Code Style & Conventions
- **Indentation**: 2 spaces (per `.editorconfig`)
- **Line endings**: LF (Unix-style)
- **Charset**: UTF-8
- **Shell scripts**: Use POSIX sh where possible; avoid bash-specific features unless needed
- **Comments**: Document why, not what; shell scripts should be clear and concise
- **Error handling**: Always check apk/dnf command success; use `set -e` for strict mode if orchestrating multiple steps
- **Naming**: Use lowercase with hyphens for containerfile names (e.g., `notetaking-toolbox`); match containerfile name to container name

## Key Files to Update When Adding Images
1. Create `ContainerFiles/{image-name}` (Containerfile syntax)
2. Create `scripts/{image-name}.sh` if setup steps needed (make executable in Containerfile)
3. Create `packages/{image-name}.packages` if package list needed
4. Add image name to `matrix.containerfile` in `.github/workflows/build-containers.yml`

## Release & Deployment Workflow
- **Manual releases**: Create a conventional commit (feat/fix/chore), push to main
- **Automated releases**: Weekly Sunday 10:00 UTC via `.github/workflows/scheduled-release.yml`
- **Release flow**: Commit → release-please creates PR → auto-merged → tag created → build-containers runs
- **Image retention**: GHCR cleanup keeps last 5 images per repository

## Important Notes
- Do not commit `cosign.key` or SIGNING_SECRET
- ContainerFiles use relative paths (e.g., `COPY ../scripts/`) from the ContainerFiles directory
- Package files should have one package per line; grep removes comments
- AUR package installations have retry logic to handle transient network errors
