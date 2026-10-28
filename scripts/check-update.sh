#!/usr/bin/env bash
#
# check-update.sh — checks Epic Games' official Linux .deb redirect endpoint
# for the latest native Epic Games Launcher (EGLv2) release version.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/network.sh"

REDIRECT_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.deb"

echo "Probing Epic Games Launcher redirect endpoint..."
HEADERS=""
for i in 1 2 3; do
  if HEADERS=$(curl -fsSI --connect-timeout 10 --max-time 30 "$REDIRECT_URL" 2>>"$ERR_LOG"); then
    break
  fi
  [ "$i" -lt 3 ] && sleep 3 || true
done

if [ -z "$HEADERS" ]; then
  die "Could not reach Epic Games redirect endpoint after 3 attempts. Last error: $(tail -n 1 "$ERR_LOG" 2>/dev/null || echo 'unknown')"
fi

LOCATION=$(printf '%s\n' "$HEADERS" | grep -i '^location:' | tail -n 1 | tr -d '\r' | awk '{print $2}' || true)
if [ -z "$LOCATION" ]; then
  die "Redirect endpoint did not return a Location header."
fi

# Extract version from .../Builds/EGLv2/<version>/Linux/EpicGamesLauncher-x86_64.deb
RAW_VERSION=$(printf '%s' "$LOCATION" | sed -nE 's|.*/Builds/EGLv2/([^/]+)/Linux/.*|\1|p' || true)
if [ -z "$RAW_VERSION" ]; then
  die "Could not parse version from redirect Location: $LOCATION"
fi

# Decode URL-encoded '+' (%2B or %252B)
LATEST_VERSION=$(printf '%s' "$RAW_VERSION" | sed -E 's/%252B/+/gi; s/%2B/+/gi')

CURRENT_VERSION=$(jq -r '.version' version.json)
echo "Latest:  $LATEST_VERSION"
echo "Current: $CURRENT_VERSION"

if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
  echo "New version available!"
  echo "update_needed=true" >> "$GITHUB_OUTPUT"
  echo "version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
else
  echo "Already up to date."
  echo "update_needed=false" >> "$GITHUB_OUTPUT"
fi
