#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Graker}"
PRODUCT_NAME="${PRODUCT_NAME:-Graker}"
VERSION="${VERSION:-1.0.2}"
IDENTIFIER="${IDENTIFIER:-com.zhixing.graker}"
DIST="${DIST:-$ROOT/dist}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Graker Local Development}"
APP="$DIST/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

cd "$ROOT"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

build_arch() {
  local arch="$1"
  local path="$ROOT/.build/$arch"
  swift build -c release --arch "$arch" --build-path "$path" >&2
  find "$path" -path "*/release/$PRODUCT_NAME" -type f -perm -111 | head -n 1
}

if [[ "${UNIVERSAL:-1}" == "1" ]]; then
  ARM_BIN="$(build_arch arm64)"
  X86_BIN="$(build_arch x86_64)"
  lipo -create "$ARM_BIN" "$X86_BIN" -output "$MACOS/$APP_NAME"
else
  swift build -c release >&2
  LOCAL_BIN="$(find "$ROOT/.build" -path "*/release/$PRODUCT_NAME" -type f -perm -111 | head -n 1)"
  cp "$LOCAL_BIN" "$MACOS/$APP_NAME"
fi

chmod +x "$MACOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$IDENTIFIER</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 ZhiXing</string>
</dict>
</plist>
PLIST

if [[ "$CODESIGN_IDENTITY" != "-" ]] &&
   ! security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$CODESIGN_IDENTITY\"" >/dev/null; then
  cat >&2 <<EOF
Missing code signing identity: $CODESIGN_IDENTITY
Run Scripts/ensure_codesign_identity.sh, or set CODESIGN_IDENTITY to another stable code signing identity.
EOF
  exit 1
fi

codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP" >/dev/null
echo "Built $APP"
file "$MACOS/$APP_NAME"
