#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Scripts/release_common.sh"
VERSION="${VERSION:-$(sayflow_read_version "$ROOT")}"
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

sayflow_write_sha256 "$DMG"
