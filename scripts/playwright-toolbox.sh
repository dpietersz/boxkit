#!/bin/sh

set -e

# Symlink distrobox shims
./distrobox-shims.sh

# Update the container
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install Node.js (LTS version via NodeSource)
apt-get install -y ca-certificates curl gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs

# Install Playwright CLI + test runner globally.
# Both packages provide a `playwright` bin, so install them in a SINGLE npm
# transaction — a sequential install hits EEXIST on /usr/bin/playwright.
# @playwright/test is the test runner that test files import; without it any
# `import { test } from '@playwright/test'` fails with MODULE_NOT_FOUND.
npm install -g playwright @playwright/test

# Set up Playwright browsers path for container
# Browsers will be installed to /opt/playwright-browsers for all users
export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
mkdir -p "$PLAYWRIGHT_BROWSERS_PATH"

# Install Playwright system dependencies (this works on Ubuntu!)
npx playwright install-deps

# Install the full Chromium browser plus Firefox and WebKit. --no-shell makes
# the full Chromium download explicit instead of relying on Playwright's default.
npx playwright install --no-shell chromium firefox webkit

# Keep the lightweight Chromium headless shell available for headless runs too.
npx playwright install chromium-headless-shell

# Set proper permissions for browsers directory
# Use 777 to allow MCP server to create browser profiles
chmod -R 777 "$PLAYWRIGHT_BROWSERS_PATH"

# Create environment setup for Playwright
cat > /etc/profile.d/playwright.sh << 'EOF'
# Playwright configuration
export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers

# Add npm global bin to PATH if not already present
NPM_GLOBAL_BIN="$(npm config get prefix)/bin"
case ":$PATH:" in
  *":$NPM_GLOBAL_BIN:"*) ;;
  *) export PATH="$NPM_GLOBAL_BIN:$PATH" ;;
esac

# Make globally-installed packages (e.g. @playwright/test) resolvable from any
# project dir. Without this, NODE_PATH is empty and test files outside this
# image's node_modules cannot `require`/`import` @playwright/test.
NPM_GLOBAL_MODULES="$(npm config get prefix)/lib/node_modules"
case ":$NODE_PATH:" in
  *":$NPM_GLOBAL_MODULES:"*) ;;
  *) export NODE_PATH="${NODE_PATH:+$NODE_PATH:}$NPM_GLOBAL_MODULES" ;;
esac
EOF

chmod +x /etc/profile.d/playwright.sh

# Create wrapper scripts in /usr/local/bin for easy export to host
# These can be exported with: distrobox-export --bin /usr/local/bin/playwright

# Playwright wrapper
cat > /usr/local/bin/playwright << 'EOF'
#!/bin/sh
export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
exec npx playwright "$@"
EOF
chmod +x /usr/local/bin/playwright

# Playwright test wrapper (common use case)
cat > /usr/local/bin/playwright-test << 'EOF'
#!/bin/sh
export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
exec npx playwright test "$@"
EOF
chmod +x /usr/local/bin/playwright-test

# Playwright codegen wrapper (for generating tests)
cat > /usr/local/bin/playwright-codegen << 'EOF'
#!/bin/sh
export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
exec npx playwright codegen "$@"
EOF
chmod +x /usr/local/bin/playwright-codegen

# Create host integration setup script
# Users run this ONCE after creating the distrobox to export commands to host
cat > /usr/local/bin/setup-host-integration << 'EOF'
#!/bin/sh
set -e

echo "Setting up Playwright host integration..."
echo ""

# Default export path
EXPORT_PATH="${1:-$HOME/.local/bin}"

# Ensure export directory exists
mkdir -p "$EXPORT_PATH"

# Export playwright commands to host
echo "Exporting playwright commands to $EXPORT_PATH..."
distrobox-export --bin /usr/local/bin/playwright --export-path "$EXPORT_PATH"
distrobox-export --bin /usr/local/bin/playwright-test --export-path "$EXPORT_PATH"
distrobox-export --bin /usr/local/bin/playwright-codegen --export-path "$EXPORT_PATH"

echo ""
echo "Host integration complete!"
echo ""
echo "Available commands on your host:"
echo "  playwright          - General Playwright CLI"
echo "  playwright-test     - Run Playwright tests"
echo "  playwright-codegen  - Generate test code with browser recorder"
echo ""
echo "Make sure $EXPORT_PATH is in your PATH."
echo ""
echo "Quick test:"
echo "  playwright --version"
echo "  playwright screenshot https://example.com screenshot.png"
EOF
chmod +x /usr/local/bin/setup-host-integration

# Clean up npm cache
npm cache clean --force

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/*

