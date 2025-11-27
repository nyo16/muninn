#!/usr/bin/env bash

set -e

# Download all precompiled NIFs and update checksums
# Run this after GitHub Actions has built all targets

echo "Downloading precompiled NIFs and generating checksums..."
echo ""

# To download all platforms (for publishing to Hex):
mix rustler_precompiled.download Muninn.Native --all --print

# To download only for local platform (for development):
# export MUNINN_BUILD=true
# mix rustler_precompiled.download Muninn.Native --only-local

echo ""
echo "Checksums updated in checksum-Elixir.Muninn.Native.exs"
echo ""
echo "Next steps:"
echo "  git add checksum-Elixir.Muninn.Native.exs"
echo "  git commit -m 'Update checksums'"
echo "  git push"
echo "  mix hex.publish"
