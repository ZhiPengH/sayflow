#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-1.0.1}"
APP="${1:-$ROOT/dist/Graker.app}"
SUPPORT_DIR="$HOME/Library/Application Support/Graker"
SETTINGS="$SUPPORT_DIR/settings.json"
PROMPTS="$SUPPORT_DIR/prompts.json"

failures=0

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  printf 'WARN %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1"
  failures=$((failures + 1))
}

graker_accessibility_permission_alert_visible() {
  if [[ "$#" -eq 0 ]]; then
    printf 'false\n'
    return 0
  fi

  /usr/bin/swift - "$@" <<'SWIFT'
import ApplicationServices
import Foundation

let needles = [
    "允许 Graker 使用辅助功能",
    "Graker 只会用辅助功能",
    "需要辅助功能权限",
    "Graker 需要辅助功能权限",
    "打开系统设置",
    "Allow Accessibility for Graker",
    "Accessibility permission required",
    "Graker needs Accessibility permission",
    "Open System Settings"
]

func appendStringValues(_ value: CFTypeRef?, to parts: inout [String]) {
    guard let value else { return }
    if let string = value as? String {
        parts.append(string)
    } else if let array = value as? [Any] {
        for item in array {
            if let string = item as? String {
                parts.append(string)
            }
        }
    }
}

func copyAttribute(_ element: AXUIElement, _ attribute: CFString, to parts: inout [String]) {
    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, attribute, &value) == .success {
        appendStringValues(value, to: &parts)
    }
}

func collectText(_ element: AXUIElement, depth: Int, parts: inout [String]) {
    guard depth > 0 else { return }

    copyAttribute(element, kAXRoleAttribute as CFString, to: &parts)
    copyAttribute(element, kAXTitleAttribute as CFString, to: &parts)
    copyAttribute(element, kAXDescriptionAttribute as CFString, to: &parts)
    copyAttribute(element, kAXValueAttribute as CFString, to: &parts)

    var childrenValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
          let children = childrenValue as? [AXUIElement] else {
        return
    }

    for child in children.prefix(120) {
        collectText(child, depth: depth - 1, parts: &parts)
    }
}

for argument in CommandLine.arguments.dropFirst() {
    guard let rawPID = Int32(argument) else { continue }
    let app = AXUIElementCreateApplication(pid_t(rawPID))
    var parts: [String] = []
    collectText(app, depth: 7, parts: &parts)
    let text = parts.joined(separator: " ")
    if needles.contains(where: { text.contains($0) }) {
        print("true")
        exit(0)
    }
}

print("false")
SWIFT
}

section "App"
if [[ -d "$APP" ]]; then
  pass "app bundle exists: $APP"
else
  fail "app bundle missing: $APP"
fi

if [[ -x "$APP/Contents/MacOS/Graker" ]]; then
  pass "app executable exists"
  file "$APP/Contents/MacOS/Graker"
else
  fail "app executable missing"
fi

if /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" >/tmp/graker-codesign.log 2>&1; then
  pass "codesign verifies"
else
  fail "codesign verification failed"
  sed -n '1,80p' /tmp/graker-codesign.log
fi

bundle_id="$(/usr/bin/defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
if [[ "$bundle_id" == "com.zhixing.graker" ]]; then
  pass "bundle id is com.zhixing.graker"
else
  fail "unexpected bundle id: ${bundle_id:-missing}"
fi

if /usr/bin/pgrep -f "$APP/Contents/MacOS/Graker" >/dev/null 2>&1; then
  pass "Graker is running from this app bundle"
else
  fail "Graker app is not running from this app bundle"
fi

section "Accessibility"
trusted="$(
  /usr/bin/swift - <<'SWIFT'
import ApplicationServices
let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
print(trusted ? "true" : "false")
SWIFT
)"
if [[ "$trusted" == "true" ]]; then
  pass "Accessibility trust is granted"
else
  fail "Accessibility trust is not granted"
  cat <<EOF
Open System Settings -> Privacy & Security -> Accessibility, then enable Graker.
Expected bundle id: com.zhixing.graker
Expected app path: $APP
EOF
fi

running_pids="$(/usr/bin/pgrep -f "$APP/Contents/MacOS/Graker" || true)"
if [[ -n "$running_pids" ]]; then
  permission_alert_visible="$(graker_accessibility_permission_alert_visible $running_pids)"
  if [[ "$permission_alert_visible" == "true" ]]; then
    fail "Graker app is showing an Accessibility permission alert"
    cat <<EOF
The probe process has Accessibility trust, but the running Graker app is still asking for it.
Open System Settings -> Privacy & Security -> Accessibility, then enable Graker for:
$APP
EOF
  else
    pass "Graker app is not showing Accessibility permission alerts"
  fi
else
  fail "Graker app is not running; cannot inspect app-specific Accessibility permission alerts"
fi

section "Settings"
if [[ -f "$SETTINGS" ]]; then
  pass "settings file exists"
else
  fail "settings file missing: $SETTINGS"
fi

if [[ -f "$PROMPTS" ]]; then
  pass "prompt file exists"
else
  fail "prompt file missing: $PROMPTS"
fi

if [[ -f "$SETTINGS" ]]; then
  /usr/bin/python3 - "$SETTINGS" <<'PY'
import json
import sys

settings = json.load(open(sys.argv[1]))
providers = settings.get("providers", [])
active = next((p for p in providers if p.get("isActive")), None)
print("active_provider=" + (active.get("displayName", "") if active else "NONE"))
print("active_model=" + (active.get("model", "") if active else "NONE"))
print("active_base_url=" + (active.get("baseURL", "") if active else "NONE"))
print("api_key_reference=" + (active.get("apiKeyReference", "") if active else "NONE"))
print("popup_position=" + settings.get("display", {}).get("positionStrategy", "missing"))
print("hotkey=" + settings.get("general", {}).get("hotKey", {}).get("displayText", "missing"))
print("launch_at_login_setting=" + str(settings.get("general", {}).get("launchAtLogin", False)).lower())
print("auto_update_setting=" + str(settings.get("general", {}).get("automaticallyChecksForUpdates", False)).lower())
print("obsidian_target=" + str(settings.get("obsidian", {}).get("targetMarkdownPath") or "NONE"))
PY
fi

if [[ -f "$SETTINGS" ]]; then
  key_ref="$(
    /usr/bin/python3 - "$SETTINGS" <<'PY'
import json
import sys

settings = json.load(open(sys.argv[1]))
active = next((p for p in settings.get("providers", []) if p.get("isActive")), None)
print(active.get("apiKeyReference", "") if active else "")
PY
  )"
  if [[ -n "$key_ref" ]] && /usr/bin/security find-generic-password -s Graker -a "$key_ref" -w >/dev/null 2>&1; then
    pass "active provider API key exists in Keychain"
  else
    fail "active provider API key is missing in Keychain"
  fi
fi

section "Package"
if [[ -f "$ROOT/dist/Graker-$VERSION.dmg" ]]; then
  pass "DMG exists"
  /usr/bin/du -sh "$ROOT/dist/Graker-$VERSION.dmg"
  /usr/bin/shasum -a 256 "$ROOT/dist/Graker-$VERSION.dmg"
else
  warn "DMG missing: $ROOT/dist/Graker-$VERSION.dmg"
fi

section "Manual Target-App Checklist"
cat <<'EOF'
After Accessibility is granted, verify this sentence with Option+G:
The market are unpredictable in short-term.

Record:
- Safari: capture works, panel near mouse, focus retained, outside click/Esc closes
- Chrome: capture works, panel near mouse, focus retained, outside click/Esc closes
- Preview PDF: capture works, panel near mouse, focus retained, outside click/Esc closes
- Word: capture works, panel near mouse, focus retained, outside click/Esc closes
- Notes: capture works, panel near mouse, focus retained, outside click/Esc closes
- TextEdit or Notes Accept: selected text becomes "The market is unpredictable in the short term."
- Revoke Accessibility and trigger again: clear permission guidance, no crash
- Installed in /Applications: launch-at-login toggle works
EOF

section "Result"
if [[ "$failures" -eq 0 ]]; then
  pass "manual acceptance probe prerequisites passed"
else
  printf 'FAIL %s prerequisite(s) failed\n' "$failures"
  exit 1
fi
