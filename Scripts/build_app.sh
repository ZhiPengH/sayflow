#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-SayFlow}"
PRODUCT_NAME="${PRODUCT_NAME:-SayFlow}"
VERSION="${VERSION:-1.2.2}"
IDENTIFIER="${IDENTIFIER:-com.zhixing.sayflow}"
DIST="${DIST:-$ROOT/dist}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-SayFlow Local Development}"
ASSETS_DIR="${ASSETS_DIR:-$ROOT/assets}"
HOT_ZONE_ICON_FILE="${HOT_ZONE_ICON_FILE:-icon_32x32@2x.png}"
APP_ICONSET_DIR="${APP_ICONSET_DIR:-$ASSETS_DIR/AppIcon.iconset}"
APP_ICON_FILE="${APP_ICON_FILE:-SayFlow.icns}"
PREBUILT_APP_ICON="${PREBUILT_APP_ICON:-$ASSETS_DIR/$APP_ICON_FILE}"
MENUBAR_ICON_FILE="${MENUBAR_ICON_FILE:-MenuBarIcon.pdf}"
APP="$DIST/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

cd "$ROOT"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
if [[ ! -f "$ASSETS_DIR/$HOT_ZONE_ICON_FILE" ]]; then
  cat >&2 <<EOF
Missing hot zone icon: $ASSETS_DIR/$HOT_ZONE_ICON_FILE
Place the provided PNG at assets/$HOT_ZONE_ICON_FILE before building.
EOF
  exit 1
fi
cp "$ASSETS_DIR/$HOT_ZONE_ICON_FILE" "$RESOURCES/$HOT_ZONE_ICON_FILE"
if [[ ! -d "$APP_ICONSET_DIR" ]]; then
  cat >&2 <<EOF
Missing app iconset: $APP_ICONSET_DIR
Place the provided app icon PNGs in assets/AppIcon.iconset before building.
EOF
  exit 1
fi
if [[ ! -f "$ASSETS_DIR/$MENUBAR_ICON_FILE" ]]; then
  cat >&2 <<EOF
Missing menu bar icon: $ASSETS_DIR/$MENUBAR_ICON_FILE
Place the provided PDF at assets/$MENUBAR_ICON_FILE before building.
EOF
  exit 1
fi
if [[ -f "$PREBUILT_APP_ICON" ]]; then
  cp "$PREBUILT_APP_ICON" "$RESOURCES/$APP_ICON_FILE"
else
  iconutil -c icns "$APP_ICONSET_DIR" -o "$RESOURCES/$APP_ICON_FILE"
fi
cp "$ASSETS_DIR/$MENUBAR_ICON_FILE" "$RESOURCES/$MENUBAR_ICON_FILE"

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
  <key>CFBundleIconFile</key>
  <string>${APP_ICON_FILE%.icns}</string>
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
