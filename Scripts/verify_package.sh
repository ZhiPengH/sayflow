#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Scripts/release_common.sh"
VERSION="${VERSION:-$(sayflow_read_version "$ROOT")}"
if ! sayflow_validate_version "$VERSION"; then
  echo "Invalid release version: $VERSION" >&2
  exit 1
fi
ALLOW_ADHOC_SIGNATURE="${ALLOW_ADHOC_SIGNATURE:-0}"
APP="$ROOT/dist/SayFlow.app"
EXECUTABLE="$APP/Contents/MacOS/SayFlow"
INFO_PLIST="$APP/Contents/Info.plist"
DMG="$ROOT/dist/SayFlow-$VERSION.dmg"
SHA_FILE="$DMG.sha256"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    detach_mount_point "$MOUNT_POINT"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
  fi
}
trap cleanup EXIT

detach_mount_point() {
  local mount_point="$1"
  if mount | grep -F "on $mount_point " >/dev/null; then
    hdiutil detach "$mount_point" >/dev/null || hdiutil detach -force "$mount_point" >/dev/null || true
  fi
}

cleanup_stale_sayflow_mounts() {
  local mount_point
  while IFS= read -r mount_point; do
    detach_mount_point "$mount_point"
    rmdir "$mount_point" 2>/dev/null || true
  done < <(mount | sed -n 's#^.* on \(/private/tmp/sayflow-dmg\.[^ ]*\) .*$#\1#p')
}

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

[[ -d "$APP" ]] || fail "app bundle exists"
pass "app bundle exists"

[[ -x "$EXECUTABLE" ]] || fail "app executable exists"
pass "app executable exists"

codesign --verify --deep --strict --verbose=2 "$APP"
pass "codesign verifies"

signature_details="$(codesign -dv --verbose=4 "$APP" 2>&1)"
if grep -F 'Signature=adhoc' <<<"$signature_details" >/dev/null; then
  if [[ "$ALLOW_ADHOC_SIGNATURE" == "1" ]]; then
    pass "codesign identity is ad-hoc for local verification"
  else
    echo "Release app must be signed with a stable code signing identity, not ad-hoc." >&2
    exit 1
  fi
else
  pass "codesign identity is stable"
fi

archs="$(lipo -archs "$EXECUTABLE")"
[[ "$archs" == *"arm64"* ]] || fail "universal build must contain arm64"
[[ "$archs" == *"x86_64"* ]] || fail "universal build must contain x86_64"
printf 'architectures=%s\n' "$archs"

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
bundle_icon="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
lsui_element="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST")"
[[ "$bundle_id" == "com.zhixing.sayflow" ]] || fail "CFBundleIdentifier mismatch"
[[ "$bundle_icon" == "SayFlow" ]] || fail "CFBundleIconFile mismatch"
[[ "$minimum_system" == "13.0" ]] || fail "LSMinimumSystemVersion mismatch"
[[ "$lsui_element" == "true" ]] || fail "LSUIElement must be true"
pass "Info.plist release fields are correct"

[[ -f "$APP/Contents/Resources/SayFlow.icns" ]] || fail "SayFlow.icns missing"
[[ -f "$APP/Contents/Resources/MenuBarIcon.pdf" ]] || fail "MenuBarIcon.pdf missing"
pass "app and menu bar icon resources exist"

[[ -f "$DMG" ]] || fail "DMG missing"
[[ -f "$SHA_FILE" ]] || fail "SHA-256 file missing"
expected_sha="$(awk '{print $1}' "$SHA_FILE")"
actual_sha="$(shasum -a 256 "$DMG" | awk '{print $1}')"
[[ "$expected_sha" == "$actual_sha" ]] || fail "DMG checksum mismatch: expected $expected_sha, got $actual_sha"
printf 'dmg_sha256=%s\n' "$actual_sha"

app_size_kb="$(du -sk "$APP" | awk '{print $1}')"
dmg_size_kb="$(du -sk "$DMG" | awk '{print $1}')"
printf 'app_size_kb=%s\n' "$app_size_kb"
printf 'dmg_size_kb=%s\n' "$dmg_size_kb"
[[ "$dmg_size_kb" -lt 30720 ]] || fail "DMG exceeds 30 MB"
pass "DMG size is below 30 MB"

cleanup_stale_sayflow_mounts
MOUNT_POINT="$(mktemp -d /private/tmp/sayflow-dmg.XXXXXX)"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG" >/dev/null
[[ -d "$MOUNT_POINT/SayFlow.app" ]] || fail "DMG missing SayFlow.app"
[[ -L "$MOUNT_POINT/Applications" ]] || fail "DMG missing Applications symlink"
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] || fail "Applications symlink target mismatch"
pass "DMG contains SayFlow.app and Applications shortcut"
