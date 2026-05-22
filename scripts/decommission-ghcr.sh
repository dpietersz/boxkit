#!/bin/sh
#
# One-shot: wipe decommissioned image packages from GHCR.
#
# Run this ONCE, after udx-toolbox has built and pushed successfully and you
# have verified it works on both laptops. After this runs, the decommissioned
# packages are gone entirely (not just old versions — the whole package).
#
# Requires: gh CLI authenticated as the package owner.
# Account type: assumes a personal user account (uses /user/packages/...).
# For an org account, swap /user/ for /orgs/<org-name>/.

set -e

DECOMMISSIONED="boxkit browser-toolbox data-toolbox notetaking-toolbox"

echo "This will permanently delete the following GHCR packages:"
for pkg in $DECOMMISSIONED; do
  echo "  - $pkg"
done
echo
printf "Type 'wipe' to confirm: "
read -r CONFIRM
[ "$CONFIRM" = "wipe" ] || { echo "Aborted."; exit 1; }

for pkg in $DECOMMISSIONED; do
  echo "── deleting package: $pkg ──"
  if gh api -X DELETE "/user/packages/container/$pkg"; then
    echo "  deleted"
  else
    echo "  WARN: delete failed (already gone, or permission issue)"
  fi
done

echo "Done."
