#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-1.3.5}"
APP="${1:-$ROOT/dist/SayFlow.app}"
SUPPORT_DIR="$HOME/Library/Application Support/SayFlow"
SETTINGS="$SUPPORT_DIR/settings.json"
PROMPTS="$SUPPORT_DIR/prompts.json"
ENV_FILE="$SUPPORT_DIR/provider.env"

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

sayflow_accessibility_permission_alert_visible() {
  if [[ "$#" -eq 0 ]]; then
    printf 'false\n'
    return 0
  fi

  /usr/bin/swift - "$@" <<'SWIFT'
import ApplicationServices
import Foundation

let needles = [
    "允许言顺使用辅助功能",
    "言顺只会用辅助功能",
    "需要辅助功能权限",
    "言顺需要辅助功能权限",
    "打开系统设置",
    "Allow Accessibility for SayFlow",
    "Accessibility permission required",
    "SayFlow needs Accessibility permission",
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

if [[ -x "$APP/Contents/MacOS/SayFlow" ]]; then
  pass "app executable exists"
  file "$APP/Contents/MacOS/SayFlow"
else
  fail "app executable missing"
fi

if /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" >/tmp/sayflow-codesign.log 2>&1; then
  pass "codesign verifies"
else
  fail "codesign verification failed"
  sed -n '1,80p' /tmp/sayflow-codesign.log
fi

bundle_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ "$bundle_id" == "com.zhixing.sayflow" ]]; then
  pass "bundle id is com.zhixing.sayflow"
else
  fail "unexpected bundle id: ${bundle_id:-missing}"
fi

if /usr/bin/pgrep -f "$APP/Contents/MacOS/SayFlow" >/dev/null 2>&1; then
  pass "SayFlow is running from this app bundle"
else
  fail "SayFlow app is not running from this app bundle"
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
Open System Settings -> Privacy & Security -> Accessibility, then enable SayFlow.
Expected bundle id: com.zhixing.sayflow
Expected app path: $APP
EOF
fi

running_pids="$(/usr/bin/pgrep -f "$APP/Contents/MacOS/SayFlow" || true)"
if [[ -n "$running_pids" ]]; then
  permission_alert_visible="$(sayflow_accessibility_permission_alert_visible $running_pids)"
  if [[ "$permission_alert_visible" == "true" ]]; then
    fail "SayFlow app is showing an Accessibility permission alert"
    cat <<EOF
The probe process has Accessibility trust, but the running SayFlow app is still asking for it.
Open System Settings -> Privacy & Security -> Accessibility, then enable SayFlow for:
$APP
EOF
  else
    pass "SayFlow app is not showing Accessibility permission alerts"
  fi
else
  fail "SayFlow app is not running; cannot inspect app-specific Accessibility permission alerts"
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
print("active_model=" + ("CONFIGURED" if active and active.get("model") else "NONE"))
print("active_base_url=" + ("CONFIGURED" if active and active.get("baseURL") else "NONE"))
reference = active.get("apiKeyReference", "") if active else ""
print("api_key_env=" + (reference.removeprefix("env://") if reference.startswith("env://") else "NONE"))
print("popup_position=" + settings.get("display", {}).get("positionStrategy", "missing"))
print("hotkey=" + settings.get("general", {}).get("hotKey", {}).get("displayText", "missing"))
print("launch_at_login_setting=" + str(settings.get("general", {}).get("launchAtLogin", False)).lower())
print("auto_update_setting=" + str(settings.get("general", {}).get("automaticallyChecksForUpdates", False)).lower())
print("obsidian_target=" + str(settings.get("obsidian", {}).get("targetMarkdownPath") or "NONE"))
PY
fi

if [[ -f "$SETTINGS" ]]; then
  key_env="$(
    /usr/bin/python3 - "$SETTINGS" <<'PY'
import json
import sys

settings = json.load(open(sys.argv[1]))
active = next((p for p in settings.get("providers", []) if p.get("isActive")), None)
reference = active.get("apiKeyReference", "") if active else ""
print(reference.removeprefix("env://") if reference.startswith("env://") else "")
PY
  )"
  if [[ -n "$key_env" && -n "${!key_env:-}" ]]; then
    pass "active provider API key exists in process environment"
  elif [[ -n "$key_env" && -f "$ENV_FILE" ]] && /usr/bin/python3 - "$ENV_FILE" "$key_env" <<'PY'
import sys

env_file, key = sys.argv[1], sys.argv[2]
for line in open(env_file):
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if stripped.startswith("export "):
        stripped = stripped[len("export "):]
    name, _, value = stripped.partition("=")
    if name.strip() == key and value.strip():
        sys.exit(0)
sys.exit(1)
PY
  then
    pass "active provider API key exists in local environment file"
  else
    warn "active provider API key is not configured in local environment"
  fi
fi

section "Package"
if [[ -f "$ROOT/dist/SayFlow-$VERSION.dmg" ]]; then
  pass "DMG exists"
  /usr/bin/du -sh "$ROOT/dist/SayFlow-$VERSION.dmg"
  /usr/bin/shasum -a 256 "$ROOT/dist/SayFlow-$VERSION.dmg"
else
  warn "DMG missing: $ROOT/dist/SayFlow-$VERSION.dmg"
fi

section "Manual Target-App Checklist"
cat <<'EOF'
After Accessibility is granted, verify this sentence with Control+Command+S:
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
