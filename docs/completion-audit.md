# SayFlow PRD Completion Audit

Objective: implement `sayflow-prd.md` as a macOS menu-bar grammar correction app for macOS 13.0+.

This audit separates implementation evidence from manual gates. A green script is not treated as final completion unless it covers the PRD requirement directly.

## Automated Evidence

Last verified commands:

- `Scripts/test.sh`: passes 95 SayFlowCore tests, validates packaging/probe script invariants, validates the debug-provider bootstrap uses the current MiMo default endpoint, and runs `swift build`.
- `Scripts/verify_package.sh`: verifies app bundle, signing, `x86_64 arm64`, `LSUIElement=true`, `LSMinimumSystemVersion=13.0`, DMG SHA-256, DMG size below 30 MB, and DMG contents. Latest ad-hoc v1.1.1 DMG SHA-256: `ce498b50ef346d25e01c863dada79ca60b0f4f68a7bc58824424c5975ed88562`; release verification still requires a stable code-signing identity.
- `Scripts/manual_acceptance_probe.sh`: verifies bundle, expected running app path, signing, provider settings, Keychain reference, package presence, and whether the running SayFlow app is still showing Accessibility onboarding/runtime permission alerts. Latest run passes for `dist/SayFlow.app`, including the Accessibility alert check.
- `Scripts/ax_selected_text_probe.sh`: verifies selected-text capture in target apps through Accessibility, including Safari/WebKit text-marker fallback.

## Requirement Matrix

| PRD requirement | Evidence | Status |
| --- | --- | --- |
| Menu-bar resident app with no Dock icon | `Package.swift`, generated `Info.plist`, `Scripts/verify_package.sh` checks `LSUIElement=true` | Automated verified |
| macOS 13.0+ | `Scripts/verify_package.sh` checks `LSMinimumSystemVersion=13.0` | Automated verified |
| Universal Apple Silicon + Intel binary | `Scripts/package_dmg.sh`, `Scripts/verify_package.sh` checks `x86_64 arm64` | Automated verified |
| DMG package with SHA-256 | `Scripts/package_dmg.sh`, `Scripts/verify_package.sh` | Automated verified |
| Accessibility onboarding explains read/replace purpose | `Sources/SayFlow/SayFlowAppDelegate.swift`, `Sources/SayFlowCore/Localization.swift`; observed in app UI | Implemented, manually observed |
| Accessibility selected-text capture | `AccessibilityTextService`, `TextCaptureResolverTests`, `Scripts/ax_selected_text_probe.sh` | Capture-only verified; full trigger still manual |
| Selection hot zone / selection-trigger wording | `SelectionHotZonePolicy`, `SelectionHotZonePolicyTests`, `SelectionHotZoneController`, `SayFlowAppDelegate.startSelectionHotZoneMonitor()` | Implemented; UI behavior still manual |
| Safari/WebKit selected-text fallback | `AccessibilityTextService.selectedTextFromTextMarkerRange`, `Scripts/ax_selected_text_probe.sh` | Capture-only verified |
| Clipboard fallback after Accessibility miss | `TextCaptureResolver`, `TextCaptureResolverTests` | Automated verified |
| Default global shortcut `Control+Command+S`, editable in General | `HotKeyConfiguration.defaultControlCommandS`, `HotKeyParserTests`, settings UI | Registration logic verified; physical hotkey delivery still manual |
| Single grammar-correction mode only; no translation/explanation/OCR/history feature surface | `PromptTemplate`, `SettingsWindow` tab layout, `ResultPanel`; repository search shows no alternate mode UI | Implemented; manual UI pass still pending |
| Provider catalog: OpenAI, DeepSeek, MiMo, Kimi, MiniMax, Doubao, Custom | `ProviderCatalog`, `ProviderTests`; MiMo default endpoint follows current MiMo OpenAI-compatible API docs | Automated verified |
| Base URL and full `/chat/completions` endpoint normalization | `EndpointNormalizer`, `ProviderTests` | Automated verified |
| Full `/responses` endpoint support for third-party debug provider | `EndpointNormalizer`, `OpenAIRequestFactory`, `ProviderTests`, live Test Run evidence | Automated and live smoke verified |
| API Key stored outside settings plaintext | `KeychainStore`, `AppSettingsTests.settingsStoreNeverSerializesPlaintextAPIKeys` | Automated verified |
| Active provider uniqueness | `AppSettings.normalizeActiveProvider`, `AppSettingsTests` | Automated verified |
| HTTPS-only provider endpoints | `ProviderSettingsValidator`, `ProviderTests` | Automated verified |
| MiMo API key header compatibility | `ProviderAuthorizationHeaders`, `ProviderTests.mimoRequestAlsoSendsAPIKeyHeader` | Automated verified |
| Legacy MiMo default endpoint migration | `ProviderLegacyDefaultMigrator`, `AppSettingsTests.settingsStoreMigratesLegacyMimoDefaultBaseURLWithoutOverwritingCustomURL`; `Scripts/test.sh` also checks debug bootstrap defaults | Automated verified |
| Structured JSON request with streaming | `OpenAIRequestFactory`, `ProviderTests` | Automated verified |
| Stream parsing for Chat Completions and Responses API | `OpenAIStreamParser`, `SSEParserTests`, fallback extractor tests | Automated verified |
| Prompt template stored in `prompts.json`, editable/import/export/default/test run | `PromptStore`, `SettingsWindow`, `PromptTemplateTests`; live Test Run previously returned valid correction | Automated plus live smoke verified |
| Missing `{{text}}` disables prompt save/test | `PromptTemplateValidator`, `SettingsWindow`, `PromptTemplateTests` | Automated verified |
| Invalid JSON shows retry warning and raw response disclosure | `CorrectionCompletionPolicy`, `RawResponseDisclosure`, tests | Automated verified |
| Settings tabs: General, Providers, Prompts, Display, Obsidian, About | `SettingsWindow.buildTabs()` | Implemented; manual UI pass still pending |
| Result panel: Corrected, diff pills, Chinese gloss, Good to know; no Origin block | `ResultPanel.swift`, `DiffPillLocatorTests`; live panel smoke evidence | Implemented and smoke verified |
| Diff pill popover text | `ResultPanelView.textView(_:clickedOnLink:)` | Implemented; manual click verification still required |
| Write, copy, Accept button order and tooltips | `ResultPanel.swift`; live AX smoke evidence | Implemented and smoke verified |
| Copy corrected text | `ResultPanel.onCopy`, live clipboard smoke evidence | Smoke verified |
| Accept replacement success in native app | `AccessibilityTextService.replaceSelection`, `AcceptReplacementFallbackTests` | Implementation verified; physical click replacement still manual |
| Accept fallback copies corrected text and warns | `AcceptReplacementFallbackTests`; live fallback smoke evidence | Verified |
| Obsidian append, create missing file/parents, H1 heading, no origin | `ObsidianWriter`, `ObsidianWriterTests`; live write smoke evidence | Automated and smoke verified |
| Obsidian invalid path validation and write-failure messages | `ObsidianTargetPathValidator`, `ObsidianWriteErrorMessage`, `ObsidianWriterTests`; `ResultPanel` uses the friendly message | Automated verified; no-permission UI scenario still manual |
| Popup follow mouse, bottom-left, center, last-closed strategies | `PopupPositioner`, `PopupPositionerTests`, Display settings UI | Automated verified; full UI pass still manual |
| Same selected text refreshes in place | `PopupPositionerTests.sameSelectedTextRefreshKeepsPreviousFrame` | Automated verified |
| Result/loading panel keeps fixed width and expands height for longer content, clamped to visible screen insets | `PopupPanelSizerTests` | Automated verified |
| Privacy: API keys in Keychain; selected text not persisted except explicit Obsidian write | `KeychainStore`, `AppSettingsTests`, `ObsidianWriterTests`; runtime keeps current text in memory for retry only | Automated verified for persistence; runtime behavior still manual |
| Network: HTTPS-only and 30s configurable timeout | `ProviderSettingsValidator`, `OpenAIRequestFactory`, `ProviderTests.requestFactoryUsesConfigurableTimeout`, `AppSettingsTests.generalSettingsClampExternalNetworkTimeout` | Automated verified |
| Offline button disabled/network prompt | `NetworkStatusMonitor`, `NetworkAvailabilityPresentation`, `NetworkAvailabilityPresentationTests`, localization | Automated verified; offline manual scenario not yet verified |
| API errors include HTTP status and provider/raw message | `OpenAIHTTPErrorMessage`, `OpenAIHTTPErrorMessageTests`, `OpenAIStreamingClient`; raw body still available in Raw response | Automated verified; live failure scenario not yet verified |
| Chinese + English localization | `LocalizationTests` | Automated verified |
| Package size below 30 MB | `Scripts/manual_acceptance_probe.sh` reports latest DMG size 892 KB | Automated verified |
| Performance budgets: panel shown before LLM response, streaming fields rendered incrementally | `SayFlowAppDelegate.checkGrammar()` calls `showLoading` before request construction; `StreamingCorrectionAccumulatorTests` verifies incremental field publication | Partially verified; real `<200ms`, token interval, first-token, and full-response timings require live manual measurement |
| Optional update check toggle | `SettingsWindow`, `UpdateCheckerTests` | Automated verified |
| Launch at login toggle | `SettingsWindow.applyLaunchAtLogin`, `LaunchAtLoginTogglePolicy` tests | Logic verified; installed-in-Applications manual gate pending |

## Manual Gates Still Open

These remain open because they require real macOS user interaction or target-app behavior that cannot be safely or reliably synthesized:

- Enable Accessibility for the exact running `dist/SayFlow.app`. Current System Settings shows `SayFlow` as off.
- Relaunch SayFlow and confirm `Scripts/manual_acceptance_probe.sh` no longer sees onboarding or runtime permission alerts.
- Press physical `Control+Command+S` in TextEdit and verify the result panel appears.
- Verify the selection hot-zone button appears after selecting text and triggers the same correction flow when clicked.
- Verify physical `Control+Command+S` capture, panel location, focus retention, and close behavior in Safari, Chrome, Preview PDF, Microsoft Word, and Notes.
- Click a diff pill and confirm the popover displays `Replaced [old] with [new]` plus Chinese explanation.
- Click Accept in a native editable app and confirm the selected text becomes `The market is unpredictable in the short term.`
- Verify an Obsidian no-permission path shows the friendly write failure message in the result panel.
- Revoke Accessibility and trigger again to confirm guidance and no crash.
- Install from DMG into `/Applications` and verify launch-at-login toggle.

## Current Completion Decision

Not complete. The implementation and automated evidence cover most PRD requirements, but the PRD acceptance criteria explicitly include real Accessibility, global hotkey, target-app capture, and native Accept replacement behavior. Those gates remain unverified until the user enables SayFlow in System Settings and performs the physical hotkey/click steps.
