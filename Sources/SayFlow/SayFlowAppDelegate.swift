import AppKit
import Foundation
import SayFlowCore

final class SayFlowAppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = AppSettingsStore(applicationSupportDirectory: ApplicationPaths.supportDirectory)
    private let promptStore = PromptStore(applicationSupportDirectory: ApplicationPaths.supportDirectory)
    private let providerSecrets = LocalEnvironmentSecretStore(applicationSupportDirectory: ApplicationPaths.supportDirectory)
    private let accessibility = AccessibilityTextService()
    private let clipboard = ClipboardService()
    private let networkMonitor = NetworkStatusMonitor()
    private let updateCheckService = UpdateCheckService()
    private let hotKeyManager = HotKeyManager()
    private let streamingClient = OpenAIStreamingClient()
    private let resultPanel = ResultPanelController()
    private let selectionHotZone = SelectionHotZoneController()
    private var settings = AppSettings.defaults()
    private var statusItem: NSStatusItem?
    private var checkGrammarItem: NSMenuItem?
    private var settingsWindow: SettingsWindowController?
    private var currentOriginalText = ""
    private var textCaptureResolver = TextCaptureResolver()
    private var selectionMouseUpMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyAppSupportIfNeeded()
        do {
            settings = try settingsStore.load()
            try? settingsStore.save(settings)
        } catch {
            settings = .defaults()
        }
        do {
            settings.prompts = try promptStore.load()
        } catch {
            _ = try? promptStore.resetToDefault()
            settings.prompts = .defaultGrammarCorrection
        }
        configureStatusItem()
        configureActions()
        startNetworkMonitor()
        startSelectionHotZoneMonitor()
        registerHotKey()
        showAccessibilityOnboardingIfNeeded()
        checkForUpdatesIfEnabled()
    }

    private func migrateLegacyAppSupportIfNeeded() {
        try? LegacyAppSupportMigration.copyMissingFiles(
            from: ApplicationPaths.legacySupportDirectory,
            to: ApplicationPaths.supportDirectory
        )
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusIcon()
        rebuildMenu()
    }

    private func configureStatusIcon() {
        guard let button = statusItem?.button else {
            return
        }
        button.title = ""
        button.image = statusIconImage()
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.toolTip = L10n.tr(.appName)
    }

    private func statusIconImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon.pdf", withExtension: nil) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let checkGrammarItem = NSMenuItem(title: L10n.tr(.checkGrammar), action: #selector(checkGrammarFromMenu), keyEquivalent: "")
        checkGrammarItem.isEnabled = networkMonitor.isOnline
        menu.addItem(checkGrammarItem)
        self.checkGrammarItem = checkGrammarItem
        syncCheckGrammarMenuShortcut()
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.tr(.settingsMenu), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.tr(.quitMenu), action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func syncCheckGrammarMenuShortcut() {
        guard let checkGrammarItem else {
            return
        }
        let shortcut = HotKeyMenuShortcutPresentation.shortcut(for: settings.general.hotKey)
        checkGrammarItem.keyEquivalent = shortcut.keyEquivalent
        checkGrammarItem.keyEquivalentModifierMask = menuModifierMask(for: shortcut.modifierFlags)
    }

    private func menuModifierMask(for carbonModifierFlags: UInt32) -> NSEvent.ModifierFlags {
        var modifierFlags: NSEvent.ModifierFlags = []
        if carbonModifierFlags & (1 << 8) != 0 {
            modifierFlags.insert(.command)
        }
        if carbonModifierFlags & (1 << 9) != 0 {
            modifierFlags.insert(.shift)
        }
        if carbonModifierFlags & (1 << 11) != 0 {
            modifierFlags.insert(.option)
        }
        if carbonModifierFlags & (1 << 12) != 0 {
            modifierFlags.insert(.control)
        }
        return modifierFlags
    }

    private func startNetworkMonitor() {
        networkMonitor.onStatusChange = { [weak self] isOnline in
            let presentation = NetworkAvailabilityPresentation.presentation(isOnline: isOnline)
            self?.checkGrammarItem?.isEnabled = presentation.menuEnabled
            self?.statusItem?.button?.toolTip = presentation.statusTitle
        }
        networkMonitor.start()
    }

    private func showAccessibilityOnboardingIfNeeded() {
        guard !accessibility.isTrusted(prompt: false) else {
            return
        }
        guard !settings.general.hasShownAccessibilityOnboarding else {
            return
        }
        settings.general.hasShownAccessibilityOnboarding = true
        try? settingsStore.save(settings)
        let alert = NSAlert()
        alert.messageText = L10n.tr(.accessibilityOnboardingTitle)
        alert.informativeText = L10n.tr(.accessibilityOnboardingMessage)
        alert.addButton(withTitle: L10n.tr(.openSystemSettings))
        alert.addButton(withTitle: L10n.tr(.notNow))
        if alert.runModal() == .alertFirstButtonReturn {
            _ = accessibility.isTrusted(prompt: true)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func checkForUpdatesIfEnabled() {
        guard settings.general.automaticallyChecksForUpdates else {
            return
        }
        updateCheckService.checkLatestRelease(currentVersion: CurrentApp.version) { [weak self] availability in
            guard case let .available(version, url) = availability else {
                return
            }
            self?.showUpdateAvailable(version: version, url: url)
        }
    }

    private func configureActions() {
        hotKeyManager.onTrigger = { [weak self] in
            self?.checkGrammar()
        }
        selectionHotZone.onTrigger = { [weak self] in
            self?.checkGrammar()
        }
        resultPanel.onCopy = { [weak self] text in
            self?.clipboard.copy(text)
        }
        resultPanel.onAccept = { [weak self] text in
            self?.accessibility.replaceSelection(with: text) ?? false
        }
        resultPanel.onRetry = { [weak self] in
            guard let self else { return }
            self.checkGrammar(sampleText: self.currentOriginalText)
        }
        resultPanel.onWrite = { [weak self] correction in
            guard let self else {
                return
            }
            guard let path = self.settings.obsidian.targetMarkdownPath, !path.isEmpty else {
                throw NSError(domain: "SayFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.tr(.chooseObsidianFirst)])
            }
            let writer = ObsidianWriter(fileURL: URL(fileURLWithPath: path))
            try writer.append(
                correction: correction,
                sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
                timestamp: Date(),
                timeZone: self.settings.obsidian.timeZone,
                template: self.settings.obsidian.writeTemplate
            )
        }
    }

    private func registerHotKey() {
        let result = hotKeyManager.register(settings.general.hotKey)
        syncCheckGrammarMenuShortcut()
        if case .failed(_, let status) = result {
            let message = String(
                format: L10n.tr(.hotkeyRegistrationFailedMessageFormat),
                settings.general.hotKey.displayText,
                status
            )
            showAlert(L10n.tr(.hotkeyRegistrationFailedTitle), message)
        }
    }

    @objc private func checkGrammarFromMenu() {
        checkGrammar()
    }

    private func checkGrammar(sampleText: String? = nil) {
        selectionHotZone.hide()
        guard networkMonitor.isOnline else {
            showAlert(L10n.tr(.networkUnavailableTitle), L10n.tr(.networkUnavailableMessage))
            return
        }
        let requiresAccessibility = GrammarTriggerPreflight.requiresAccessibilityPermission(sampleText: sampleText)
        if requiresAccessibility {
            let shouldRequestSystemPrompt = AccessibilityPermissionPromptPolicy.shouldRequestSystemPrompt(for: .grammarTrigger)
            guard accessibility.isTrusted(prompt: shouldRequestSystemPrompt) else {
                showAccessibilityPermissionHelp()
                return
            }
        }

        let captureDecision = textCaptureResolver.resolve(
            sampleText: sampleText,
            accessibilityText: requiresAccessibility ? accessibility.selectedText() : nil,
            clipboardText: requiresAccessibility ? clipboard.currentString() : nil,
            clipboardChangeCount: clipboard.changeCount
        )
        guard case .captured(let selectedText) = captureDecision else {
            showAlert(L10n.tr(.noSelectedTextTitle), L10n.tr(.noSelectedTextMessage))
            return
        }

        currentOriginalText = selectedText
        resultPanel.showLoading(originalText: selectedText, settings: settings)
        guard let provider = settings.activeProvider else {
            resultPanel.showError(L10n.tr(.noActiveProvider), raw: nil, originalText: selectedText, settings: settings)
            return
        }
        guard let apiKey = providerSecrets.read(reference: provider.apiKeyReference), !apiKey.isEmpty else {
            resultPanel.showError(L10n.tr(.missingAPIKey), raw: nil, originalText: selectedText, settings: settings)
            openSettings()
            return
        }

        do {
            let request = try OpenAIRequestFactory.makeRequest(
                configuration: provider,
                apiKey: apiKey,
                timeout: TimeInterval(settings.general.networkTimeoutSeconds),
                prompt: settings.prompts,
                selectedText: selectedText
            )
            streamingClient.stream(
                request: request,
                onSnapshot: { [weak self] snapshot in
                    guard let self else { return }
                    self.resultPanel.update(snapshot: snapshot, originalText: selectedText, settings: self.settings)
                },
                onError: { [weak self] message, raw in
                    guard let self else { return }
                    self.resultPanel.showError(message, raw: raw, originalText: selectedText, settings: self.settings)
                },
                onComplete: { [weak self] snapshot in
                    guard let self else { return }
                    self.resultPanel.update(snapshot: snapshot, originalText: selectedText, settings: self.settings)
                }
            )
        } catch {
            resultPanel.showError(error.localizedDescription, raw: nil, originalText: selectedText, settings: settings)
        }
    }

    @objc private func openSettings() {
        selectionHotZone.hide()
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                settings: settings,
                settingsStore: settingsStore,
                providerSecrets: providerSecrets,
                onSettingsChanged: { [weak self] newSettings in
                    self?.settings = newSettings
                    try? self?.promptStore.save(newSettings.prompts)
                    self?.registerHotKey()
                },
                onTestRun: { [weak self] sample in
                    self?.checkGrammar(sampleText: sample)
                }
            )
        }
        settingsWindow?.update(settings: settings)
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAlert(_ title: String, _ message: String) {
        selectionHotZone.hide()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func showAccessibilityPermissionHelp() {
        selectionHotZone.hide()
        let alert = NSAlert()
        alert.messageText = L10n.tr(.accessibilityTitle)
        alert.informativeText = L10n.tr(.accessibilityMessage)
        alert.addButton(withTitle: L10n.tr(.openSystemSettings))
        alert.addButton(withTitle: L10n.tr(.notNow))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startSelectionHotZoneMonitor() {
        guard selectionMouseUpMonitor == nil else {
            return
        }
        selectionMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self else {
                return
            }
            let mouse = NSEvent.mouseLocation
            guard !self.selectionHotZone.contains(point: mouse) else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.updateSelectionHotZone(near: mouse)
            }
        }
    }

    private func updateSelectionHotZone(near mouse: CGPoint) {
        let trusted = accessibility.isTrusted(prompt: false)
        let selectedText = trusted ? accessibility.selectedText() : nil
        let ownBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.zhixing.sayflow"
        let decision = SelectionHotZonePolicy.decision(
            accessibilityTrusted: trusted,
            selectedText: selectedText,
            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            ownBundleIdentifier: ownBundleIdentifier
        )
        switch decision {
        case .show(let text):
            selectionHotZone.show(near: mouse, selectedText: text)
        case .hide:
            selectionHotZone.hide()
        }
    }

    private func showUpdateAvailable(version: String, url: URL?) {
        let alert = NSAlert()
        alert.messageText = L10n.tr(.updateAvailableTitle)
        alert.informativeText = String(format: L10n.tr(.updateAvailableMessageFormat), version)
        alert.addButton(withTitle: L10n.tr(.openReleasePage))
        alert.addButton(withTitle: L10n.tr(.notNow))
        if alert.runModal() == .alertFirstButtonReturn, let url {
            NSWorkspace.shared.open(url)
        }
    }
}
