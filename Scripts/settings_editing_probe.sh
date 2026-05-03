#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'PASS %s\n' "$1"
}

[[ -f Sources/SayFlow/StandardEditMenu.swift ]] || fail "StandardEditMenu.swift is missing"
grep -q 'StandardEditMenu.install()' Sources/SayFlow/main.swift || fail "main.swift does not install the standard Edit menu"

for selector in 'undo:' 'redo:' 'cut:' 'copy:' 'paste:' 'selectAll:'; do
  grep -q "$selector" Sources/SayFlow/StandardEditMenu.swift || fail "missing Edit menu selector $selector"
done

for key in 'keyEquivalent: "z"' 'keyEquivalent: "x"' 'keyEquivalent: "c"' 'keyEquivalent: "v"' 'keyEquivalent: "a"'; do
  grep -q "$key" Sources/SayFlow/StandardEditMenu.swift || fail "missing standard shortcut $key"
done

grep -q 'keyEquivalentModifierMask = \[.command, .shift\]' Sources/SayFlow/StandardEditMenu.swift || fail "missing Command+Shift+Z redo shortcut"
grep -q 'NSApp.mainMenu = mainMenu' Sources/SayFlow/StandardEditMenu.swift || fail "standard Edit menu is not assigned to NSApp.mainMenu"

for control in \
  hotKeyField \
  timeoutField \
  apiKeyField \
  baseURLField \
  modelField \
  temperatureField \
  systemPromptView \
  userPromptView \
  obsidianPathField \
  obsidianTemplateView; do
  grep -q "$control" Sources/SayFlow/SettingsWindow.swift || fail "SettingsWindow missing editable control $control"
done

grep -q 'textView.allowsUndo = true' Sources/SayFlow/SettingsWindow.swift || fail "settings NSTextView editors do not enable Undo"

pass "Settings editable controls use the standard macOS Edit menu"
