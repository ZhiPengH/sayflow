#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Scripts/release_common.sh"

VERSION="${VERSION:-$(sayflow_read_version "$ROOT")}"
if ! sayflow_validate_version "$VERSION"; then
  echo "Invalid release version: $VERSION" >&2
  exit 1
fi

TEAM_ID="UTZUZ8U2J2"
DEVELOPER_ID_NAME="Developer ID Application: ZHIPENG HUANG ($TEAM_ID)"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-$DEVELOPER_ID_NAME}"
KEYCHAIN_PROFILE="${NOTARY_PROFILE:-sayflow-notary}"
APP="$ROOT/dist/SayFlow.app"
ZIP="$ROOT/dist/SayFlow-$VERSION.zip"
DMG="$ROOT/dist/SayFlow-$VERSION.dmg"
STAGE="$ROOT/.build/dmg-stage"

NOTARYTOOL="$(sayflow_find_xcode_tool notarytool)" || {
  echo "notarytool not found. Install Xcode from the App Store and launch it once." >&2
  exit 1
}
STAPLER="$(sayflow_find_xcode_tool stapler)" || {
  echo "stapler not found. Install Xcode from the App Store and launch it once." >&2
  exit 1
}

step() {
  echo ""
  echo "==> $1"
}

step "[1/8] Verify Developer ID Application identity in keychain"
security find-identity -v -p codesigning | grep -F "$DEVELOPER_ID_NAME" >/dev/null
echo "Found: $DEVELOPER_ID_NAME"

step "[2/8] Verify notarytool keychain profile"
if ! "$NOTARYTOOL" history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
  echo "Missing or invalid notarytool keychain profile '$KEYCHAIN_PROFILE'." >&2
  echo "Run this yourself in your own Terminal (never paste passwords into chat):" >&2
  echo "" >&2
  echo "  /Applications/Xcode.app/Contents/Developer/usr/bin/notarytool store-credentials $KEYCHAIN_PROFILE --apple-id YOUR_APPLE_ID --team-id $TEAM_ID" >&2
  echo "" >&2
  echo "You will be asked for:" >&2
  echo "1. An app-specific password created at https://appleid.apple.com" >&2
  echo "   (Sign-In and Security > App-Specific Passwords)." >&2
  echo "2. The same password again, to confirm storing it in your keychain." >&2
  exit 1
fi
echo "Keychain profile authenticated: $KEYCHAIN_PROFILE"

step "[3/8] Build SayFlow $VERSION with Developer ID + Hardened Runtime + secure timestamp"
VERSION="$VERSION" CODESIGN_IDENTITY="$CODESIGN_IDENTITY" "$ROOT/Scripts/build_app.sh"

step "[4/8] Verify signature authority, timestamp, and runtime flags"
codesign --verify --deep --strict --verbose=2 "$APP"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP" 2>&1)"
grep -F 'Authority=Developer ID Application:' <<<"$SIGNATURE_DETAILS" >/dev/null
grep -F 'Timestamp=' <<<"$SIGNATURE_DETAILS" >/dev/null
grep -iE 'flags=.*runtime|Runtime Version=' <<<"$SIGNATURE_DETAILS" >/dev/null
echo "$SIGNATURE_DETAILS" | grep -E 'Authority|TeamIdentifier|Timestamp|flags|Runtime'

step "[5/8] Notarize SayFlow.app and staple the ticket"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
"$NOTARYTOOL" submit "$ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait
"$STAPLER" staple "$APP"
"$STAPLER" validate "$APP"

step "[6/8] Gatekeeper assessment for SayFlow.app"
SPCTL_OUTPUT="$(spctl --assess --type execute --verbose=4 "$APP" 2>&1)"
echo "$SPCTL_OUTPUT"
grep -F 'source=Notarized Developer ID' <<<"$SPCTL_OUTPUT" >/dev/null

step "[7/8] Package, notarize, and staple the DMG"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/SayFlow.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname SayFlow -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
sayflow_write_sha256 "$DMG"
"$NOTARYTOOL" submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
"$STAPLER" staple "$DMG"
"$STAPLER" validate "$DMG"

step "[8/8] Full package verification"
VERSION="$VERSION" "$ROOT/Scripts/verify_package.sh"

echo ""
echo "Official $VERSION artifacts are notarized and stapled:"
echo "  $APP"
echo "  $DMG"
echo "  $DMG.sha256"
