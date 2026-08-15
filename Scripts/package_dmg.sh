#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$VERSION_FILE")}"
DIST="$ROOT/dist"
APP="$DIST/SayFlow.app"
DMG="$DIST/SayFlow-$VERSION.dmg"
STAGE="$ROOT/.build/dmg-stage"

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-$("$ROOT/Scripts/ensure_codesign_identity.sh")}"
export CODESIGN_IDENTITY
VERSION="$VERSION" "$ROOT/Scripts/build_app.sh"

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/SayFlow.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
  -volname "SayFlow" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

shasum -a 256 "$DMG" | tee "$DMG.sha256"
