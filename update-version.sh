#!/usr/bin/env bash
#
# update-version.sh — update version.json + package.nix for a new Epic Games Launcher release.
#
# Usage: ./update-version.sh [version]
#   version   Optional. The new version (e.g. 0.105.0+gc9a97d0).
#             If omitted, queries the official Epic Games redirect endpoint automatically.

set -euo pipefail

REDIRECT_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.deb"

resolve_latest_version() {
  local headers location raw_ver
  headers=$(curl -fsSI --connect-timeout 10 --max-time 30 "$REDIRECT_URL")
  location=$(printf '%s\n' "$headers" | grep -i '^location:' | tail -n 1 | tr -d '\r' | awk '{print $2}')
  raw_ver=$(printf '%s' "$location" | sed -nE 's|.*/Builds/EGLv2/([^/]+)/Linux/.*|\1|p')
  printf '%s' "$raw_ver" | sed -E 's/%252B/+/gi; s/%2B/+/gi'
}

get_sri_hash() {
  local url="$1" temp_file raw_hash
  temp_file="$(mktemp)"
  trap 'rm -f "$temp_file"' RETURN
  curl -fsSL --connect-timeout 10 --max-time 300 --retry 3 --retry-delay 3 --retry-all-errors "$url" -o "$temp_file"
  raw_hash=$(sha256sum "$temp_file" | cut -d' ' -f1)
  nix hash convert --hash-algo sha256 --to sri "$raw_hash"
}

version="${1:-}"
if [ -z "$version" ]; then
  echo "No version specified; resolving latest version from Epic Games..."
  version=$(resolve_latest_version)
fi

if [ -z "$version" ]; then
  echo "Error: Could not determine target version." >&2
  exit 1
fi

encoded_version="${version//+/%2B}"
url="https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${encoded_version}/Linux/EpicGamesLauncher-x86_64.deb"

echo "------------------------------------------------"
echo "Target Version: $version"
echo "Download URL:   $url"
echo "------------------------------------------------"

echo "Downloading and hashing archive..."
hash_sri=$(get_sri_hash "$url")
[ -n "$hash_sri" ] || { echo "Error: failed to hash archive." >&2; exit 1; }
echo "  SRI: $hash_sri"

echo "Updating package.nix ..."
temp_file=$(mktemp)
sed "s|hash = \"sha256-.*\";|hash = \"$hash_sri\";|" package.nix > "$temp_file"
mv "$temp_file" package.nix

echo "Updating version.json ..."
cat > version.json << EOF
{
  "version": "$version",
  "url": "$url"
}
EOF

echo "------------------------------------------------"
echo "Success! Updated Epic Games Launcher to ${version}"
echo "  Hash: ${hash_sri}"
echo "------------------------------------------------"
