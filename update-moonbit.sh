#!/usr/bin/env bash
set -euo pipefail
set -x
PKG_FILE="pkgs/moonbit/default.nix"
BINARY_URL="https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz"
CORE_URL="https://cli.moonbitlang.com/cores/core-latest.tar.gz"

OLD_BINARY_HASH=$(grep -A 1 'url = "'$BINARY_URL'"' "$PKG_FILE" | grep 'hash' | sed -e 's/.*hash = "\(.*\)";/\1/')
OLD_CORE_HASH=$(grep -A 1 'url = "'$CORE_URL'"' "$PKG_FILE" | grep 'hash' | sed -e 's/.*hash = "\(.*\)";/\1/')

echo "Current binary hash: $OLD_BINARY_HASH"
echo "Current core hash:   $OLD_CORE_HASH"

NEW_BINARY_HASH=$(nix-prefetch-url --sri "$BINARY_URL")
NEW_CORE_HASH=$(nix-prefetch-url --sri "$CORE_URL")

echo "Latest binary hash: $NEW_BINARY_HASH"
echo "Latest core hash:   $NEW_CORE_HASH"

if [ "$OLD_BINARY_HASH" != "$NEW_BINARY_HASH" ] || [ "$OLD_CORE_HASH" != "$NEW_CORE_HASH" ]; then
  echo "New version found! Updating $PKG_FILE..."
  # Use `sed` to find and replace the old hashes with the new ones.
  sed -i "s|hash = \"$OLD_BINARY_HASH\";|hash = \"$NEW_BINARY_HASH\";|" "$PKG_FILE"
  sed -i "s|hash = \"$OLD_CORE_HASH\";|hash = \"$NEW_CORE_HASH\";|" "$PKG_FILE"
  echo "Update complete. The Nix expression is now pointing to the latest version."
else
  echo "Package is already up-to-date. No changes needed."
fi
