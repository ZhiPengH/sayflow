# SayFlow / 言顺

Native macOS menu-bar grammar correction app for Chinese English learners. It reads selected text with Accessibility, sends it to an OpenAI-compatible provider as streaming JSON, and renders corrected English, change explanations, Chinese gloss, and a learning tip in a floating panel.

## Requirements

- macOS 13.0+
- Swift 6.x Command Line Tools are enough for local builds
- Accessibility permission for selected-text capture and Accept replacement

## Development

Run the local verification suite:

```bash
Scripts/test.sh
```

Build a debug executable:

```bash
swift build
```

Build a signed `.app` bundle:

```bash
UNIVERSAL=0 Scripts/build_app.sh
```

Build a universal DMG and SHA-256 checksum:

```bash
Scripts/package_dmg.sh
Scripts/verify_package.sh
```

Manual macOS permission and target-app acceptance steps are documented in
[`docs/acceptance-checklist.md`](docs/acceptance-checklist.md).
After building the app, run `Scripts/manual_acceptance_probe.sh` to check the
current app bundle, local provider configuration, DMG checksum, and
Accessibility gate before doing the target-app manual pass.

The package manifest intentionally uses the older SwiftPM manifest format because the available Command Line Tools expose a mismatched PackageDescription interface/dylib for newer manifests. The source itself is Swift 5 mode and builds with the current Swift compiler.

## Storage

- Settings: `~/Library/Application Support/SayFlow/settings.json`
- Prompt template: `~/Library/Application Support/SayFlow/prompts.json`
- API keys: `~/Library/Application Support/SayFlow/provider.env` or process environment variables, never in JSON settings
- Obsidian writes: append-only to the Markdown file selected in Settings

## Implemented Scope

- Menu-bar-only app with no Dock icon when launched from the generated `.app`
- First-launch Accessibility guidance explaining selected-text capture and Accept replacement
- Default global shortcut `⌃⌘S`, editable for Control+Command or Option plus letter shortcuts
- Selection hot-zone button after selecting text, reusing the same grammar correction flow
- Accessibility selected-text capture, clipboard fallback prompt, and Accept replacement
- OpenAI, DeepSeek, Xiaomi MiMo, Kimi, MiniMax, Doubao, NVIDIA, and custom OpenAI-compatible providers
- MiMo requests include the provider's `api-key` header in addition to Bearer auth
- Base URL, full `/chat/completions`, or full `/responses` endpoint normalization
- Streaming SSE parsing and incremental structured JSON rendering
- Editable System prompt slots PromptA-PromptE with fixed internal `{{text}}`, reset, import/export, and test run
- Floating result panel with Corrected, diff highlighting/popover, Chinese gloss, Good to know, copy, Accept, and Obsidian write actions
- Popup position strategies: follow mouse, bottom-left, center, last closed position
- Append-only Obsidian Markdown writer with missing-file creation
- Chinese and English UI localization following the system language
- Optional automatic GitHub Releases update check
- DMG packaging script with SHA-256 output

## Debugging A Third-Party Responses Endpoint

For an OpenAI-compatible proxy that exposes the Responses API, configure the Custom provider with:

- Base URL / Endpoint: the full `https://.../v1/responses` endpoint
- Model: the proxy model name
- API Key: paste it in Settings so SayFlow stores it in the local `provider.env` file

SayFlow detects `/v1/responses` automatically and sends a Responses API request with `stream: true` and `text.format.type = json_object`. The SSE parser accepts both incremental `response.output_text.delta` chunks and completed events that contain the final output object. Other base URLs continue to use `/chat/completions`.

You can also configure a local debug provider from the terminal without writing the key to project files:

```bash
SAYFLOW_DEBUG_ENDPOINT="https://example.com/v1/responses" \
SAYFLOW_DEBUG_MODEL="model-name" \
SAYFLOW_DEBUG_API_KEY="sk-..." \
Scripts/configure_debug_provider.sh
```

The script updates `~/Library/Application Support/SayFlow/settings.json` and stores the key in `~/Library/Application Support/SayFlow/provider.env` under `SAYFLOW_CUSTOM_API_KEY`.
