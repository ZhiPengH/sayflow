# SayFlow v1.1.6 Acceptance Checklist

Use this checklist after building `dist/SayFlow.app` or installing `dist/SayFlow-1.1.6.dmg`.
Some items require macOS Accessibility permission and must be verified by a logged-in user.

## Automated Gates

Run these from the repository root.

```bash
Scripts/test.sh
Scripts/package_dmg.sh
Scripts/verify_package.sh
Scripts/manual_acceptance_probe.sh
```

Expected evidence:

- `Scripts/test.sh` reports all SayFlowCore tests passed and `swift build` completes.
- `Scripts/package_dmg.sh` creates `dist/SayFlow.app`, `dist/SayFlow-1.1.6.dmg`, and `dist/SayFlow-1.1.6.dmg.sha256`.
- `Scripts/verify_package.sh` checks codesign, `x86_64` + `arm64`,
  `LSUIElement=true`, `LSMinimumSystemVersion=13.0`, SHA-256, DMG size below
  30 MB, and the mounted DMG contents using a fixed temporary mount point.
- `Scripts/manual_acceptance_probe.sh` reports bundle, signing, provider, local environment,
  package, and Accessibility status without printing API keys. When SayFlow is
  running, it also checks that the app itself is not still showing first-launch
  onboarding or runtime Accessibility permission alerts. It exits non-zero until
  SayFlow is running from the expected app bundle and the permission gate is
  actually clear for the app.
- `Scripts/ax_selected_text_probe.sh <app> "<expected text>"` can be used while
  a target app has selected text. It checks the same AX selected-text path used
  by SayFlow, including WebKit text-marker fallback for Safari.

## Provider Smoke Test

Configure Settings -> Providers -> Custom with an OpenAI-compatible provider.

For a Responses API endpoint, use the full `/v1/responses` endpoint. SayFlow should send:

- `stream: true`
- `text.format.type: json_object`
- `instructions` and `input`

Acceptance:

- Test Run returns a correction with `corrected`, `changes`, `translation_zh`, and optional `good_to_know`.
- Invalid JSON displays the retry warning, shows a collapsed Raw response control, and expands the raw response on click instead of crashing.
- API errors show the HTTP status and raw body.
- Prompt import rejects templates that fail the same validation as Save, including a missing `{{text}}` placeholder.

## Accessibility Permission

1. Launch `dist/SayFlow.app`.
2. Confirm the first-run dialog explains that Accessibility is used to read selected text and replace text only when Accept is clicked.
3. Click Open System Settings and grant Accessibility permission to SayFlow.
4. Quit and relaunch SayFlow.
5. Revoke Accessibility permission and trigger SayFlow again.

Acceptance:

- With permission granted, selected-text capture works in the target apps below.
- With permission revoked, SayFlow shows a permission explanation and does not crash.

## Target App Selected-Text Capture

For each app, select the sentence `The market are unpredictable in short-term.` and trigger SayFlow with `Control+Command+S`.

- Safari
- Google Chrome
- Preview with a PDF
- Microsoft Word
- Notes

Acceptance for each app:

- SayFlow captures the selected sentence, not stale clipboard text.
- The floating panel appears near the mouse by default.
- The panel keeps the original app focused.
- The panel closes on outside click or Escape.

Record evidence:

| App | Capture works | Panel near mouse | Focus retained | Notes |
| --- | --- | --- | --- | --- |
| Safari |  |  |  |  |
| Chrome |  |  |  |  |
| Preview PDF |  |  |  |  |
| Word |  |  |  |  |
| Notes |  |  |  |  |

Optional AX capture-only probe:

```bash
Scripts/ax_selected_text_probe.sh Safari "The market are unpredictable in short-term."
Scripts/ax_selected_text_probe.sh "Google Chrome" "The market are unpredictable in short-term."
Scripts/ax_selected_text_probe.sh Preview "The market are unpredictable in short-term."
Scripts/ax_selected_text_probe.sh "Microsoft Word" "The market are unpredictable in short-term."
```

This verifies selected-text capture only. It does not replace the full `Control+Command+S`
manual pass because the full pass must also verify hotkey delivery, panel
position, focus retention, close behavior, and Accept replacement.

## Result Panel UI

Use a correction with at least two changes.

Acceptance:

- Corrected section is visible.
- Origin section is not present.
- Changed spans are highlighted as green diff pills.
- Clicking a diff pill opens a popover with `Replaced [old] with [new]` plus the Chinese explanation.
- Chinese gloss appears under Corrected.
- Good to know appears when provided and is hidden when absent.
- Buttons are ordered left to right: write to Obsidian, copy, Accept.
- Write and copy buttons are icon-only with tooltips.
- Copy and write buttons flash a green check for about 1.6 seconds after success.

## Accept Replacement

In a native editable app such as Notes or TextEdit:

1. Select `The market are unpredictable in short-term.`
2. Trigger SayFlow.
3. Wait for the corrected sentence.
4. Click Accept.

Acceptance:

- The selected text in the original app is replaced with `The market is unpredictable in the short term.`
- SayFlow does not steal permanent focus from the original app.
- If the target app refuses Accessibility replacement, SayFlow copies the corrected text to the clipboard and shows a clear warning.

## Obsidian Append

1. In Settings -> Obsidian, choose a new Markdown file path.
2. Trigger SayFlow and click the write icon.
3. Open the target file.

Acceptance:

- Missing parent directories and the Markdown file are created.
- The file starts with `# SayFlow Inbox` when newly created.
- The new entry is appended rather than overwriting existing content.
- The entry includes corrected text, changes with explanations, Chinese translation, and Good to know.
- The original incorrect sentence is not saved.
- A no-permission path shows a clear error and does not lose the correction.

## Popup Position

Verify all Settings -> Display popup position options:

- Follow mouse
- Bottom left
- Center
- Last closed position

Acceptance:

- The panel stays within the active screen bounds on every strategy.
- On multiple displays, follow-mouse uses the display containing the pointer.
- Re-triggering the same selected text refreshes in place and does not jump.

## General Settings

Acceptance:

- Default shortcut is `Control+Command+S` (`⌃⌘S`).
- Changing the shortcut in General re-registers the global hotkey.
- Launch at login can be toggled when the app is installed in Applications.
- Automatic update checking can be toggled and only runs when enabled.
