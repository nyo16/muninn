#!/bin/bash
set -e

# Muninn Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 0.3.0

VERSION=${1:-$(grep -m1 '@version' mix.exs | sed 's/.*"\(.*\)".*/\1/')}

if [ -z "$VERSION" ]; then
  echo "Error: Could not determine version"
  echo "Usage: ./scripts/release.sh [version]"
  exit 1
fi

echo "==> Releasing Muninn v${VERSION}"
echo ""

# Ensure we're on a clean working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "Error: Working directory is not clean. Please commit or stash changes."
  exit 1
fi

# Ensure we're on master branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "master" ]; then
  echo "Warning: Not on master branch (currently on: $CURRENT_BRANCH)"
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check version in mix.exs matches
MIX_VERSION=$(grep -m1 '@version' mix.exs | sed 's/.*"\(.*\)".*/\1/')
if [ "$VERSION" != "$MIX_VERSION" ]; then
  echo "Error: Version mismatch!"
  echo "  Requested: $VERSION"
  echo "  mix.exs:   $MIX_VERSION"
  echo ""
  echo "Please update @version in mix.exs first."
  exit 1
fi

# Pull latest changes
echo "==> Pulling latest changes..."
git pull origin "$CURRENT_BRANCH"

# Run tests
echo "==> Running tests..."
MUNINN_BUILD=true mix test

# Create and push the tag
echo "==> Creating tag v${VERSION}..."
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"

echo ""
echo "==> Tag v${VERSION} pushed!"
echo ""
echo "Next steps:"
echo "  1. Wait for GitHub Actions to build all precompiled NIFs"
echo "     https://github.com/nyo16/muninn/actions"
echo ""
echo "  2. Once builds complete, download checksums:"
echo "     mix rustler_precompiled.download Muninn.Native --all --print"
echo ""
echo "  3. Update checksum file and commit:"
echo "     git add checksum-Elixir.Muninn.Native.exs"
echo "     git commit -m 'Update checksums for v${VERSION}'"
echo "     git push"
echo ""
echo "  4. Publish to Hex.pm:"
echo "     mix hex.publish"
echo ""
echo "Done!"
