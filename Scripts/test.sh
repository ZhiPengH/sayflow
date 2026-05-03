#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p .build/local-tests .build/module-cache
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache"
for script in Scripts/*.sh; do
  bash -n "$script"
done
test -x Scripts/verify_package.sh
test -x Scripts/ax_selected_text_probe.sh
test -x Scripts/run_manual_test_app.sh
grep -q 'mktemp -d /private/tmp/graker-dmg.XXXXXX' Scripts/verify_package.sh
grep -q 'graker_accessibility_permission_alert_visible' Scripts/manual_acceptance_probe.sh
grep -q '需要辅助功能权限' Scripts/manual_acceptance_probe.sh
grep -q 'fail "Graker app is not running' Scripts/manual_acceptance_probe.sh
grep -q 'https://api.mimo-v2.com/v1' Scripts/configure_debug_provider.sh
! grep -q 'https://api.mimo.mi.com/v1' Scripts/configure_debug_provider.sh
grep -q 'APP_NAME="${APP_NAME:-Graker}"' Scripts/build_app.sh
grep -q 'DIST="${DIST:-$ROOT/dist}"' Scripts/build_app.sh
grep -q 'VERSION="${VERSION:-1.0.2}"' Scripts/build_app.sh
grep -q 'VERSION="${VERSION:-1.0.2}"' Scripts/package_dmg.sh
grep -q 'VERSION="${VERSION:-1.0.2}"' Scripts/verify_package.sh
grep -q 'Version 1.0.2' Sources/GrakerCore/Localization.swift
grep -q 'ResultPanelLayoutMetrics.panelWidth' Sources/Graker/ResultPanel.swift
grep -q 'applyWrappingConstraints()' Sources/Graker/ResultPanel.swift
grep -q 'CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Graker Local Development}"' Scripts/build_app.sh
grep -q 'ensure_codesign_identity.sh' Scripts/package_dmg.sh
grep -q 'dist/Graker.app' Scripts/run_manual_test_app.sh
grep -q 'Signature=adhoc' Scripts/verify_package.sh
CODESIGN_IDENTITY=- APP_NAME=TestApp IDENTIFIER=com.hzp.testapp DIST="$ROOT/build" UNIVERSAL=0 Scripts/build_app.sh >/tmp/graker-test-app-build.log
test -d build/TestApp.app
test -x build/TestApp.app/Contents/MacOS/TestApp
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/build/TestApp.app/Contents/Info.plist")" = "com.hzp.testapp"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$ROOT/build/TestApp.app"
swiftc -swift-version 5 Sources/GrakerCore/*.swift Tests/GrakerCoreTests/*.swift -o .build/local-tests/GrakerCoreTests
.build/local-tests/GrakerCoreTests
swift build
