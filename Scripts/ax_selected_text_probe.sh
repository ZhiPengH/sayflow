#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
EXPECTED="${2:-}"

PROBE_APP_NAME="$APP_NAME" PROBE_EXPECTED="$EXPECTED" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

func env(_ key: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[key],
          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return value
}

func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}

let trusted = AXIsProcessTrustedWithOptions([
    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
] as CFDictionary)
print("accessibility_trusted=\(trusted)")
guard trusted else {
    exit(2)
}

let requestedApp = env("PROBE_APP_NAME")
let app: NSRunningApplication?
if let requestedApp {
    let lower = requestedApp.lowercased()
    app = NSWorkspace.shared.runningApplications.first { running in
        running.localizedName?.lowercased() == lower ||
        running.bundleIdentifier?.lowercased() == lower ||
        running.bundleURL?.lastPathComponent.lowercased().replacingOccurrences(of: ".app", with: "") == lower ||
        running.executableURL?.lastPathComponent.lowercased() == lower ||
        running.localizedName?.lowercased().contains(lower) == true
    }
} else {
    app = NSWorkspace.shared.frontmostApplication
}

guard let app else {
    print("app_found=false")
    exit(3)
}

print("app_found=true")
print("app_name=\(app.localizedName ?? "unknown")")
print("bundle_id=\(app.bundleIdentifier ?? "unknown")")
print("pid=\(app.processIdentifier)")

let appElement = AXUIElementCreateApplication(app.processIdentifier)
var focused: CFTypeRef?
let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
print("focused_result=\(focusedResult.rawValue)")
guard focusedResult == .success, let focused else {
    exit(4)
}

let focusedElement = focused as! AXUIElement
var role: CFTypeRef?
if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &role) == .success {
    print("focused_role=\(role as? String ?? "unknown")")
}

var selected: CFTypeRef?
let selectedResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selected)
print("selected_result=\(selectedResult.rawValue)")
var selectedText = normalized(selected as? String ?? "")
if selectedText.isEmpty {
    var markerRange: CFTypeRef?
    let markerRangeResult = AXUIElementCopyAttributeValue(focusedElement, "AXSelectedTextMarkerRange" as CFString, &markerRange)
    print("text_marker_range_result=\(markerRangeResult.rawValue)")
    if markerRangeResult == .success, let markerRange {
        var markerText: CFTypeRef?
        let markerTextResult = AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            "AXStringForTextMarkerRange" as CFString,
            markerRange,
            &markerText
        )
        print("text_marker_string_result=\(markerTextResult.rawValue)")
        if markerTextResult == .success {
            selectedText = normalized(markerText as? String ?? "")
        }
    }
}
print("selected_length=\(selectedText.count)")
print("selected_text_begin")
print(selectedText)
print("selected_text_end")

if let expected = env("PROBE_EXPECTED") {
    if selectedText == normalized(expected) {
        print("expected_match=true")
    } else {
        print("expected_match=false")
        exit(5)
    }
}
SWIFT
