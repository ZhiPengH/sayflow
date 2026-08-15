# SayFlow PRD Completion Audit

Objective: implement `sayflow-prd.md` as a macOS menu-bar grammar correction app for macOS 13.0+.

This audit separates implementation evidence from manual gates. A green script is not treated as final completion unless it covers the PRD requirement directly.

## Automated Evidence

Last verified commands:

- `Scripts/test.sh`: passes 161 SayFlowCore tests, validates packaging/probe script invariants, validates the local debug-provider bootstrap, and runs `swift build`.
- `Scripts/verify_package.sh`: passes for the stable local-signed `x86_64 arm64` app bundle, `LSUIElement=true`, `LSMinimumSystemVersion=13.0`, DMG SHA-256, size below 30 MB, and mounted contents. Final v1.3.4 DMG SHA-256: `4e6370e21652360df4f5a98612dd0952a1a2f74e33a43beb28a36419e454e045`.
- `Scripts/manual_acceptance_probe.sh`: verifies bundle, expected running app path, signing, redacted provider settings, local environment reference, package presence, and whether the running SayFlow app is still showing Accessibility onboarding/runtime permission alerts.
- `Scripts/ax_selected_text_probe.sh`: verifies selected-text capture through Accessibility; direct `AXSelectedText` values that are missing or blank now fall back to the Safari/WebKit text-marker range.
- Real X/Chrome E2E: Accept replaced the draft DOM from `比如想着` with the English correction, after which the original draft was restored; no post was submitted.

## Requirement Matrix

| PRD requirement | Evidence | Status |
| --- | --- | --- |
| Menu-bar resident app with no Dock icon | `Package.swift`, generated `Info.plist`, `Scripts/verify_package.sh` checks `LSUIElement=true` | Automated verified |
| macOS 13.0+ | `Scripts/verify_package.sh` checks `LSMinimumSystemVersion=13.0` | Automated verified |
| Universal Apple Silicon + Intel binary | `Scripts/package_dmg.sh`, `Scripts/verify_package.sh` checks `x86_64 arm64` | Automated verified |
| DMG package with SHA-256 | `Scripts/package_dmg.sh`, `Scripts/verify_package.sh` | Automated verified |
| Accessibility onboarding explains read/replace purpose | `Sources/SayFlow/SayFlowAppDelegate.swift`, `Sources/SayFlowCore/Localization.swift`; observed in app UI | Implemented, manually observed |
| Accessibility selected-text capture | `AccessibilityTextService`, `AccessibilitySelectedTextPolicy`, `AccessibilitySelectedTextPolicyTests`, `TextCaptureResolverTests`, `Scripts/ax_selected_text_probe.sh` | Direct and empty-value marker-fallback paths automated; remaining target-app capture matrix is manual |
| Selection hot zone / selection-trigger wording | `SelectionHotZonePolicy`, `SelectionHotZonePolicyTests`, `SelectionHotZoneController`, `SayFlowAppDelegate.startSelectionHotZoneMonitor()` | Implemented; UI behavior still manual |
| Safari/WebKit selected-text fallback | `AccessibilityTextService.selectedTextFromTextMarkerRange`, `AccessibilitySelectedTextPolicyTests`, `Scripts/ax_selected_text_probe.sh` | Empty direct AX value fallback automated |
| Clipboard fallback after Accessibility miss | `TextCaptureResolver`, `TextCaptureResolverTests` | Automated verified |
| Default global shortcut `Control+Command+S`, editable in General | `HotKeyConfiguration.defaultControlCommandS`, `HotKeyParserTests`, settings UI | Registration logic verified; physical hotkey delivery still manual |
| Single grammar-correction mode only; no translation/explanation/OCR/history feature surface | `PromptTemplate`, `SettingsWindow` tab layout, `ResultPanel`; repository search shows no alternate mode UI | Implemented; manual UI pass still pending |
| Provider catalog: OpenAI, DeepSeek, MiMo, Kimi, MiniMax, Doubao, NVIDIA, Z.ai(CN), Custom | `ProviderCatalog`, `ProviderTests`; MiMo, MiniMax, NVIDIA, and Z.ai(CN) use provider-specific chat-completions endpoints | Automated verified |
| Base URL and full `/chat/completions` endpoint normalization | `EndpointNormalizer`, `ProviderTests` | Automated verified |
| Full `/responses` endpoint support for third-party debug provider | `EndpointNormalizer`, `OpenAIRequestFactory`, `ProviderTests`, live Test Run evidence | Automated and live smoke verified |
| API Key stored outside settings plaintext | `LocalEnvironmentSecretStore`, `ProviderSecretReference`, `AppSettingsTests.settingsStoreNeverSerializesPlaintextAPIKeys` | Automated verified |
| Active provider uniqueness | `AppSettings.normalizeActiveProvider`, `AppSettingsTests` | Automated verified |
| HTTPS-only provider endpoints | `ProviderSettingsValidator`, `ProviderTests` | Automated verified |
| MiMo API key header compatibility | `ProviderAuthorizationHeaders`, `ProviderTests.mimoRequestAlsoSendsAPIKeyHeader` | Automated verified |
| Legacy MiMo default endpoint migration | `ProviderLegacyDefaultMigrator`, `AppSettingsTests.settingsStoreMigratesLegacyMimoDefaultBaseURLWithoutOverwritingCustomURL`; `Scripts/test.sh` also checks debug bootstrap defaults | Automated verified |
| Structured JSON request with streaming | `OpenAIRequestFactory`, `ProviderTests` | Automated verified |
| Stream parsing for Chat Completions and Responses API | `OpenAIStreamParser`, `SSEParserTests`, fallback extractor tests | Automated verified |
| Accept cancels active streaming and ignores late callbacks | `SayFlowAppDelegate` cancels `OpenAIStreamingClient` and gates snapshot/error/completion callbacks by request-attempt ID | Implemented; real X/Chrome Accept completed without stale panel updates |
| Prompt template stored in `prompts.json`, editable PromptA-PromptE System slots, fixed internal `{{text}}`, import/export/default/test run | `PromptStore`, `SettingsWindow`, `PromptTemplateTests`; live Test Run previously returned valid correction | Automated plus live smoke verified |
| User Prompt remains hidden in Settings and legacy `userPrompt` imports render through fixed `{{text}}` | `PromptTemplate`, `SettingsWindow`, `settings_editing_probe.sh`, `PromptTemplateTests` | Automated verified |
| Invalid JSON shows retry warning and raw response disclosure | `CorrectionCompletionPolicy`, `RawResponseDisclosure`, tests | Automated verified |
| Settings tabs: General, Providers, Prompts, Display, Obsidian, About | `SettingsWindow.buildTabs()` | Implemented; manual UI pass still pending |
| Result panel: Corrected, diff pills, Chinese gloss, Good to know; no Origin block | `ResultPanel.swift`, `DiffPillLocatorTests`; live panel smoke evidence | Implemented and smoke verified |
| Diff pill popover text | `ResultPanelView.textView(_:clickedOnLink:)` | Implemented; manual click verification still required |
| Write, insert, Accept button order and tooltips | `ResultPanel.swift`; live AX smoke evidence | Implemented and smoke verified |
| Auto-copy corrected text | `ResultPresentationPolicy`, `ResultPanel.onCopy`, tests | Automated verified |
| Accept replacement success in native app | `AccessibilityTextService.replaceSelection`, `AcceptReplacementFallbackTests` | Implementation verified; physical native-app click replacement still manual |
| Browser Accept avoids AX false-success and performs guarded deferred paste | `WebEditorReplacementPolicy`, `AcceptReplacementFallback`, `DeferredPasteFocusPolicy`, focused-selection verification, and their tests | Automated; real X/Chrome draft E2E verified, restored afterward, no post submitted |
| Deferred paste is session-scoped and target-directed | Captured PID/bundle/launch date, session/operation IDs, frontmost/selection/clipboard checks, and `CGEvent.postToPid` | Automated policy coverage and real X/Chrome E2E verified; an unconfirmed required selection cancels auto-paste and leaves the correction on the clipboard |
| Obsidian prepend, create missing file/parents, H1 heading, no origin | `ObsidianWriter`, `ObsidianWriterTests`; live write smoke evidence | Automated and smoke verified |
| Obsidian invalid path validation and write-failure messages | `ObsidianTargetPathValidator`, `ObsidianWriteErrorMessage`, `ObsidianWriterTests`; `ResultPanel` uses the friendly message | Automated verified; no-permission UI scenario still manual |
| Popup follow mouse, bottom-left, center, last-closed strategies | `PopupPositioner`, `PopupPositionerTests`, Display settings UI | Automated verified; full UI pass still manual |
| Same selected text refreshes in place | `PopupPositionerTests.sameSelectedTextRefreshKeepsPreviousFrame` | Automated verified |
| Result/loading panel keeps fixed width and expands height for longer content, clamped to visible screen insets | `PopupPanelSizerTests` | Automated verified |
| Privacy: API keys in local environment storage; selected text not persisted except explicit Obsidian write | `LocalEnvironmentSecretStore`, `LocalEnvironmentFile`, `AppSettingsTests`, `ObsidianWriterTests`; runtime keeps current text in memory for retry only | Automated verified for persistence; runtime behavior still manual |
| Network: HTTPS-only and 30s configurable timeout | `ProviderSettingsValidator`, `OpenAIRequestFactory`, `ProviderTests.requestFactoryUsesConfigurableTimeout`, `AppSettingsTests.generalSettingsClampExternalNetworkTimeout` | Automated verified |
| Offline button disabled/network prompt | `NetworkStatusMonitor`, `NetworkAvailabilityPresentation`, `NetworkAvailabilityPresentationTests`, localization | Automated verified; offline manual scenario not yet verified |
| API errors include HTTP status and provider/raw message | `OpenAIHTTPErrorMessage`, `OpenAIHTTPErrorMessageTests`, `OpenAIStreamingClient`; raw body still available in Raw response | Automated verified; live failure scenario not yet verified |
| Chinese + English localization | `LocalizationTests` | Automated verified |
| Package size below 30 MB | `Scripts/verify_package.sh` checks the final v1.3.4 DMG size | Automated verified |
| Performance budgets: panel shown before LLM response, streaming fields rendered incrementally | `SayFlowAppDelegate.checkGrammar()` calls `showLoading` before request construction; `StreamingCorrectionAccumulatorTests` verifies incremental field publication | Partially verified; real `<200ms`, token interval, first-token, and full-response timings require live manual measurement |
| Optional update check toggle | `SettingsWindow`, `UpdateCheckerTests` | Automated verified |
| Launch at login toggle | `SettingsWindow.applyLaunchAtLogin`, `LaunchAtLoginTogglePolicy` tests | Logic verified; installed-in-Applications manual gate pending |

## Manual Gates Still Open

These remain open because they require real macOS user interaction or target-app behavior that cannot be safely or reliably synthesized:

- Enable Accessibility for the exact running `dist/SayFlow.app`. Current System Settings shows `SayFlow` as off.
- Relaunch SayFlow and confirm `Scripts/manual_acceptance_probe.sh` no longer sees onboarding or runtime permission alerts.
- Press physical `Control+Command+S` in TextEdit and verify the result panel appears.
- Verify the selection hot-zone button appears after selecting text and triggers the same correction flow when clicked.
- Verify physical `Control+Command+S` capture, panel location, focus retention, and close behavior in Safari, Preview PDF, Microsoft Word, and Notes. The X/Chrome Accept path has separate completed E2E evidence.
- Click a diff pill and confirm the popover displays `Replaced [old] with [new]` plus Chinese explanation.
- Click Accept in a native editable app and confirm the selected text becomes `The market is unpredictable in the short term.`
- Verify an Obsidian no-permission path shows the friendly write failure message in the result panel.
- Revoke Accessibility and trigger again to confirm guidance and no crash.
- Install from DMG into `/Applications` and verify launch-at-login toggle.

## Current Completion Decision

Not complete. The browser Accept path is now verified end to end in a real X/Chrome draft, including restoration without posting. The remaining PRD gates require physical Accessibility, global-hotkey, capture, and native-app replacement checks in the other target apps.
