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
test -x Scripts/settings_editing_probe.sh
Scripts/settings_editing_probe.sh
grep -q 'mktemp -d /private/tmp/sayflow-dmg.XXXXXX' Scripts/verify_package.sh
grep -q 'sayflow_accessibility_permission_alert_visible' Scripts/manual_acceptance_probe.sh
grep -q '需要辅助功能权限' Scripts/manual_acceptance_probe.sh
grep -q 'fail "SayFlow app is not running' Scripts/manual_acceptance_probe.sh
! grep -q 'https://api.mimo.mi.com/v1' Scripts/configure_debug_provider.sh
grep -q 'APP_NAME="${APP_NAME:-SayFlow}"' Scripts/build_app.sh
grep -q 'DIST="${DIST:-$ROOT/dist}"' Scripts/build_app.sh
grep -q 'VERSION="${VERSION:-1.3.1}"' Scripts/build_app.sh
grep -q 'VERSION="${VERSION:-1.3.1}"' Scripts/package_dmg.sh
grep -q 'VERSION="${VERSION:-1.3.1}"' Scripts/verify_package.sh
grep -q 'ALLOW_ADHOC_SIGNATURE="${ALLOW_ADHOC_SIGNATURE:-0}"' Scripts/verify_package.sh
grep -q 'Version 1.3.1' Sources/SayFlowCore/Localization.swift
test -f assets/AppIcon.iconset/icon_512x512@2x.png
test -f assets/SayFlow.icns
test -f assets/MenuBarIcon.pdf
grep -q 'APP_ICON_FILE="${APP_ICON_FILE:-SayFlow.icns}"' Scripts/build_app.sh
grep -q 'PREBUILT_APP_ICON="${PREBUILT_APP_ICON:-$ASSETS_DIR/$APP_ICON_FILE}"' Scripts/build_app.sh
grep -q 'MENUBAR_ICON_FILE="${MENUBAR_ICON_FILE:-MenuBarIcon.pdf}"' Scripts/build_app.sh
grep -q 'CFBundleIconFile' Scripts/build_app.sh
grep -q 'iconutil -c icns' Scripts/build_app.sh
grep -q 'MenuBarIcon.pdf' Sources/SayFlowCore/MenuBarIconPresentation.swift
grep -q 'MenuBarIconPresentation.displayedPointSize' Sources/SayFlow/SayFlowAppDelegate.swift
grep -q 'button.image?.isTemplate = true' Sources/SayFlow/SayFlowAppDelegate.swift
! grep -q 'statusItem?.button?.title' Sources/SayFlow/SayFlowAppDelegate.swift
! grep -q 'keyEquivalent: "g"' Sources/SayFlow/SayFlowAppDelegate.swift
grep -q 'HotKeyMenuShortcutPresentation.shortcut' Sources/SayFlow/SayFlowAppDelegate.swift
grep -q 'checkGrammarItem.keyEquivalentModifierMask' Sources/SayFlow/SayFlowAppDelegate.swift
test -f assets/icon_32x32@2x.png
grep -q 'HOT_ZONE_ICON_FILE="${HOT_ZONE_ICON_FILE:-icon_32x32@2x.png}"' Scripts/build_app.sh
grep -q 'triggerIconFileName = "icon_32x32@2x.png"' Sources/SayFlowCore/SelectionHotZonePolicy.swift
grep -q 'triggerIconPointSize = 32' Sources/SayFlowCore/SelectionHotZonePolicy.swift
grep -q 'triggerPanelSideLength = 32' Sources/SayFlowCore/SelectionHotZonePolicy.swift
grep -q 'triggerButtonInset = 0' Sources/SayFlowCore/SelectionHotZonePolicy.swift
grep -q 'triggerButtonTitle = ""' Sources/SayFlowCore/SelectionHotZonePolicy.swift
grep -q 'SelectionHotZonePresentation.triggerPanelSideLength' Sources/SayFlow/SelectionHotZoneController.swift
grep -q 'displayText: "⌃⌘S"' Sources/SayFlowCore/AppSettings.swift
grep -q "displayText: '⌃⌘S'" Scripts/configure_debug_provider.sh
grep -q 'Control+Command+S' Sources/SayFlowCore/Localization.swift
grep -q 'ResultPanelLayoutMetrics.panelWidth' Sources/SayFlow/ResultPanel.swift
grep -q 'applyWrappingConstraints()' Sources/SayFlow/ResultPanel.swift
grep -q 'correctedHeightConstraint' Sources/SayFlow/ResultPanel.swift
grep -q 'updateDynamicTextHeights()' Sources/SayFlow/ResultPanel.swift
grep -q 'layoutManager?.usedRect' Sources/SayFlow/ResultPanel.swift
! grep -q 'themePopup' Sources/SayFlow/SettingsWindow.swift
! grep -q 'darkAqua' Sources/SayFlow/ResultPanel.swift
! grep -q 'case dark' Sources/SayFlowCore/AppSettings.swift
! grep -q 'case system' Sources/SayFlowCore/AppSettings.swift
grep -q 'panel.appearance = lightAppearance' Sources/SayFlow/SelectionHotZoneController.swift
grep -q 'button.appearance = lightAppearance' Sources/SayFlow/SelectionHotZoneController.swift
grep -q 'container.appearance = lightAppearance' Sources/SayFlow/SelectionHotZoneController.swift
! grep -q 'darkAqua' Sources/SayFlow/SelectionHotZoneController.swift
grep -q 'CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-SayFlow Local Development}"' Scripts/build_app.sh
grep -q 'ensure_codesign_identity.sh' Scripts/package_dmg.sh
grep -q 'dist/SayFlow.app' Scripts/run_manual_test_app.sh
grep -q 'Signature=adhoc' Scripts/verify_package.sh
grep -q 'SAYFLOW_OPENAI_API_KEY' Sources/SayFlowCore/Provider.swift
grep -q 'provider.env' Sources/SayFlow/AppServices.swift
grep -q 'NSComboBox' Sources/SayFlow/SettingsWindow.swift
grep -q 'private let obsidianPathField = NSComboBox()' Sources/SayFlow/SettingsWindow.swift
grep -q 'panel.canChooseDirectories = false' Sources/SayFlow/SettingsWindow.swift
grep -q 'ObsidianRecentMarkdownFiles.adding' Sources/SayFlow/SettingsWindow.swift
grep -q 'ObsidianRecentMarkdownFiles.displayTitle' Sources/SayFlow/SayFlowAppDelegate.swift
grep -q 'saveFileMenu' Sources/SayFlow/SayFlowAppDelegate.swift
grep -q 'chooseMarkdown: "打开"' Sources/SayFlowCore/Localization.swift
grep -q 'saveFileMenu: "保存文件"' Sources/SayFlowCore/Localization.swift
grep -q 'recentMarkdownPaths' Sources/SayFlowCore/AppSettings.swift
grep -q 'ProviderModelOptions.recommendedModels' Sources/SayFlow/SettingsWindow.swift
grep -q 'SAYFLOW_NVIDIA_API_KEY' Sources/SayFlowCore/Provider.swift
grep -q 'https://integrate.api.nvidia.com/v1' Sources/SayFlowCore/Provider.swift
grep -q 'deepseek-ai/deepseek-v4-flash' Sources/SayFlowCore/Provider.swift
grep -q 'SAYFLOW_Z_AI_CN_API_KEY' Sources/SayFlowCore/Provider.swift
grep -q 'https://open.bigmodel.cn/api/paas/v4' Sources/SayFlowCore/Provider.swift
grep -q 'GLM-4.7-FlashX' Sources/SayFlowCore/Provider.swift
! rg -q 'nvapi-[A-Za-z0-9]' .
! grep -q 'KeychainStore' Sources/SayFlow/AppServices.swift Sources/SayFlow/SettingsWindow.swift Sources/SayFlow/SayFlowAppDelegate.swift
! grep -q 'import Security' Sources/SayFlow/AppServices.swift
! grep -q 'security find-generic-password' Scripts/manual_acceptance_probe.sh
! grep -q 'https://api.mimo-v2.com/v1' Scripts/configure_debug_provider.sh
legacy_brand_pattern='[Gg]raker'
if rg -n "$legacy_brand_pattern" --glob '!AGENTS.md' --glob '!Sources/SayFlowCore/LegacyAppMigration.swift' --glob '!Tests/SayFlowCoreTests/LegacyAppMigrationTests.swift'; then
  echo "Unexpected legacy brand reference outside migration files." >&2
  exit 1
fi
CODESIGN_IDENTITY=- APP_NAME=TestApp IDENTIFIER=com.hzp.testapp DIST="$ROOT/build" UNIVERSAL=0 Scripts/build_app.sh >/tmp/sayflow-test-app-build.log
test -d build/TestApp.app
test -x build/TestApp.app/Contents/MacOS/TestApp
test -f build/TestApp.app/Contents/Resources/SayFlow.icns
test -f build/TestApp.app/Contents/Resources/MenuBarIcon.pdf
test -f build/TestApp.app/Contents/Resources/icon_32x32@2x.png
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$ROOT/build/TestApp.app/Contents/Info.plist")" = "SayFlow"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/build/TestApp.app/Contents/Info.plist")" = "com.hzp.testapp"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$ROOT/build/TestApp.app"
swiftc -swift-version 5 Sources/SayFlowCore/*.swift Tests/SayFlowCoreTests/*.swift -o .build/local-tests/SayFlowCoreTests
.build/local-tests/SayFlowCoreTests
swift build
