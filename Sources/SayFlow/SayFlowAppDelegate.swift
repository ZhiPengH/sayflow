import AppKit
import Foundation
import SayFlowCore

private struct CorrectionTarget {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let launchDate: Date?
}

private struct CorrectionSession {
    let id: UUID
    let target: CorrectionTarget?
    let originalText: String
}

final class SayFlowAppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = AppSettingsStore(applicationSupportDirectory: ApplicationPaths.supportDirectory)
    private let promptStore = PromptStore(applicationSupportDirectory: ApplicationPaths.supportDirectory)
    private let providerSecrets = LocalEnvironmentSecretStore(applicationSupportDirectory: ApplicationPaths.supportDirectory)
    private let accessibility = AccessibilityTextService()
    private let clipboard = ClipboardService()
    private let speech = SpeechService()
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
    private var selectionMouseDownMonitor: Any?
    private var selectionMouseUpMonitor: Any?
    private var selectionMouseDownLocation: CGPoint?
    private var selectionClipboardFallbackToken = 0
    private var currentCorrectionSession: CorrectionSession?
    private var currentRequestAttemptID: UUID?
    private var acceptingSessionID: UUID?
    private var pendingPasteOperationID: UUID?

    private static let deferredPasteRetryDelay: TimeInterval = 0.05
    private static let maximumDeferredPasteRetryCount = 20

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
        guard let url = Bundle.main.url(forResource: MenuBarIconPresentation.resourceFileName, withExtension: nil),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        let sourcePointSize = Int(ceil(max(image.size.width, image.size.height)))
        let pointSize = CGFloat(MenuBarIconPresentation.displayedPointSize(forSourcePointSize: sourcePointSize))
        image.size = NSSize(width: pointSize, height: pointSize)
        return image
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let checkGrammarItem = NSMenuItem(title: L10n.tr(.checkGrammar), action: #selector(checkGrammarFromMenu), keyEquivalent: "")
        checkGrammarItem.isEnabled = networkMonitor.isOnline
        menu.addItem(checkGrammarItem)
        self.checkGrammarItem = checkGrammarItem
        syncCheckGrammarMenuShortcut()
        menu.addItem(saveFileMenuItem())
        menu.addItem(sceneSwitchMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.tr(.settingsMenu), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.tr(.quitMenu), action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func saveFileMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr(.saveFileMenu), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let recentPaths = Array(settings.obsidian.recentMarkdownPaths.prefix(ObsidianRecentMarkdownFiles.limit))
        if recentPaths.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr(.noRecentMarkdownFiles), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for path in recentPaths {
                let recentItem = NSMenuItem(
                    title: ObsidianRecentMarkdownFiles.displayTitle(for: path),
                    action: #selector(selectRecentObsidianFile(_:)),
                    keyEquivalent: ""
                )
                recentItem.target = self
                recentItem.representedObject = path
                if path == settings.obsidian.targetMarkdownPath {
                    recentItem.state = .on
                }
                submenu.addItem(recentItem)
            }
        }
        item.submenu = submenu
        return item
    }

    private func sceneSwitchMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr(.sceneSwitchMenu), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for scene in PromptSceneMenuPresentation.items(for: settings.prompts) {
            let sceneItem = NSMenuItem(
                title: scene.title,
                action: #selector(selectPromptScene(_:)),
                keyEquivalent: ""
            )
            sceneItem.target = self
            sceneItem.representedObject = scene.id
            sceneItem.state = scene.isActive ? .on : .off
            submenu.addItem(sceneItem)
        }
        item.submenu = submenu
        return item
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
        resultPanel.onSpeak = { [weak self] text in
            self?.speech.speak(text)
        }
        resultPanel.onInsert = { [weak self] originalText, correctedText in
            guard let self else {
                return false
            }
            let replacement = ResultPresentationPolicy.insertReplacement(
                originalText: originalText,
                correctedText: correctedText
            )
            let action = InsertReplacementFallback.action(
                accessibilityReplacementSucceeded: self.accessibility.replaceSelection(with: replacement),
                replacement: replacement
            )
            switch action {
            case .showInsertedFeedback:
                return true
            case .pasteReplacementThroughClipboard(let replacement):
                self.clipboard.copy(replacement)
                return self.accessibility.pasteClipboardIntoFocusedSelection()
            case .showFailureAndClosePanelAfterDelay:
                return false
            }
        }
        resultPanel.onAccept = { [weak self] text in
            guard let self else {
                return .pasteSchedulingFailed
            }
            guard let session = self.currentCorrectionSession,
                  self.acceptingSessionID != session.id else {
                return .pasteSchedulingFailed
            }
            self.acceptingSessionID = session.id
            self.currentRequestAttemptID = nil
            self.streamingClient.cancel()
            let transport = WebEditorReplacementPolicy.transport(
                bundleIdentifier: session.target?.bundleIdentifier
            )
            let accessibilityReplacementSucceeded = transport == .accessibility
                ? self.accessibility.replaceSelection(with: text)
                : false
            let action = AcceptReplacementFallback.replacementAction(
                accessibilityReplacementSucceeded: accessibilityReplacementSucceeded,
                correctedText: text
            )
            var expectedClipboardChangeCount: Int?
            return AcceptReplacementFallback.execute(
                action: action,
                copyToClipboard: {
                    self.clipboard.copy($0)
                    expectedClipboardChangeCount = self.clipboard.changeCount
                },
                closePanel: { self.resultPanel.close() },
                pasteAfterPanelClose: { [weak self] replacement in
                    guard let self, let expectedClipboardChangeCount else {
                        return false
                    }
                    return self.scheduleClipboardPaste(
                        replacement: replacement,
                        expectedClipboardChangeCount: expectedClipboardChangeCount,
                        session: session
                    )
                }
            )
        }
        resultPanel.onRetry = { [weak self] in
            guard let self else { return }
            self.checkGrammar(sampleText: self.currentOriginalText, inheritedSession: self.currentCorrectionSession)
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

    private func scheduleClipboardPaste(
        replacement: String,
        expectedClipboardChangeCount: Int,
        session: CorrectionSession
    ) -> Bool {
        guard currentCorrectionSession?.id == session.id,
              let target = session.target,
              let targetApplication = matchingRunningApplication(for: target),
              clipboard.changeCount == expectedClipboardChangeCount,
              clipboard.currentString() == replacement else {
            return false
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if frontmostPID != target.processIdentifier,
           !targetApplication.activate(options: [.activateAllWindows]) {
            return false
        }

        let operationID = UUID()
        pendingPasteOperationID = operationID
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deferredPasteRetryDelay) { [weak self] in
            self?.attemptClipboardPaste(
                replacement: replacement,
                expectedClipboardChangeCount: expectedClipboardChangeCount,
                session: session,
                operationID: operationID,
                retryCount: 0
            )
        }
        return true
    }

    private func attemptClipboardPaste(
        replacement: String,
        expectedClipboardChangeCount: Int,
        session: CorrectionSession,
        operationID: UUID,
        retryCount: Int
    ) {
        guard let target = session.target else {
            cancelPasteOperation(operationID)
            return
        }

        let targetApplication = matchingRunningApplication(for: target)
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: currentCorrectionSession?.id == session.id && pendingPasteOperationID == operationID,
            targetIsRunning: targetApplication != nil,
            clipboardMatches: clipboard.changeCount == expectedClipboardChangeCount && clipboard.currentString() == replacement,
            selectionMatches: accessibility.focusedSelectionMatches(
                session.originalText,
                processIdentifier: target.processIdentifier
            ),
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            targetPID: target.processIdentifier,
            retryCount: retryCount,
            maximumRetryCount: Self.maximumDeferredPasteRetryCount
        )

        switch action {
        case .paste:
            pendingPasteOperationID = nil
            _ = accessibility.pasteClipboardIntoFocusedSelection(processIdentifier: target.processIdentifier)
        case .retryAfterDelay:
            guard let targetApplication,
                  targetApplication.activate(options: [.activateAllWindows]) else {
                cancelPasteOperation(operationID)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.deferredPasteRetryDelay) { [weak self] in
                self?.attemptClipboardPaste(
                    replacement: replacement,
                    expectedClipboardChangeCount: expectedClipboardChangeCount,
                    session: session,
                    operationID: operationID,
                    retryCount: retryCount + 1
                )
            }
        case .cancel:
            cancelPasteOperation(operationID)
        }
    }

    private func matchingRunningApplication(for target: CorrectionTarget) -> NSRunningApplication? {
        guard let application = NSRunningApplication(processIdentifier: target.processIdentifier),
              !application.isTerminated,
              application.bundleIdentifier == target.bundleIdentifier else {
            return nil
        }
        if let launchDate = target.launchDate, application.launchDate != launchDate {
            return nil
        }
        return application
    }

    private func cancelPasteOperation(_ operationID: UUID) {
        if pendingPasteOperationID == operationID {
            pendingPasteOperationID = nil
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

    @objc private func selectRecentObsidianFile(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else {
            return
        }
        settings.obsidian.targetMarkdownPath = path
        settings.obsidian.recentMarkdownPaths = ObsidianRecentMarkdownFiles.adding(
            path,
            to: settings.obsidian.recentMarkdownPaths
        )
        do {
            try settingsStore.save(settings)
            settingsWindow?.update(settings: settings)
            rebuildMenu()
        } catch {
            showAlert(L10n.tr(.failedSaveSettings), error.localizedDescription)
        }
    }

    @objc private func selectPromptScene(_ sender: NSMenuItem) {
        guard let promptID = sender.representedObject as? String,
              PromptTemplate.systemPromptIDs.contains(promptID) else {
            return
        }
        settings.prompts.activeSystemPromptID = promptID
        do {
            try promptStore.save(settings.prompts)
            settingsWindow?.update(settings: settings)
            rebuildMenu()
        } catch {
            showAlert(L10n.tr(.failedSaveSettings), error.localizedDescription)
        }
    }

    private func checkGrammar(sampleText: String? = nil, inheritedSession: CorrectionSession? = nil) {
        let correctionID = inheritedSession?.id ?? UUID()
        let target = inheritedSession?.target ?? (sampleText == nil ? currentExternalTarget() : nil)
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

        let accessibilityText = requiresAccessibility ? accessibility.selectedText() : nil
        let captureDecision = textCaptureResolver.resolve(
            sampleText: sampleText,
            accessibilityText: accessibilityText,
            clipboardText: requiresAccessibility ? clipboard.currentString() : nil,
            clipboardChangeCount: clipboard.changeCount
        )
        switch captureDecision {
        case .captured(let selectedText):
            checkGrammar(
                for: selectedText,
                correctionID: correctionID,
                target: target
            )
        case .needsClipboardCopyPrompt:
            let fallbackAction = ClipboardShortcutCapturePolicy.action(
                sampleText: sampleText,
                requiresAccessibility: requiresAccessibility,
                captureDecision: captureDecision
            )
            guard fallbackAction == .tryCopyShortcut,
                  accessibility.copyFocusedSelectionToClipboard() else {
                showAlert(L10n.tr(.noSelectedTextTitle), L10n.tr(.noSelectedTextMessage))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
                self?.checkGrammarFromClipboardFallback(correctionID: correctionID, target: target)
            }
            return
        }
    }

    private func currentExternalTarget() -> CorrectionTarget? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ownPID else {
            return nil
        }
        return CorrectionTarget(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            launchDate: application.launchDate
        )
    }

    private func checkGrammarFromClipboardFallback(correctionID: UUID, target: CorrectionTarget?) {
        let captureDecision = textCaptureResolver.resolve(
            sampleText: nil,
            accessibilityText: nil,
            clipboardText: clipboard.currentString(),
            clipboardChangeCount: clipboard.changeCount
        )
        guard case .captured(let selectedText) = captureDecision else {
            showAlert(L10n.tr(.noSelectedTextTitle), L10n.tr(.noSelectedTextMessage))
            return
        }
        checkGrammar(
            for: selectedText,
            correctionID: correctionID,
            target: target
        )
    }

    private func checkGrammar(
        for selectedText: String,
        correctionID: UUID,
        target: CorrectionTarget?
    ) {
        let correctionMode = CorrectionModePolicy.mode(for: selectedText)
        let requestAttemptID = UUID()
        currentCorrectionSession = CorrectionSession(
            id: correctionID,
            target: target,
            originalText: selectedText
        )
        currentRequestAttemptID = requestAttemptID
        acceptingSessionID = nil
        pendingPasteOperationID = nil
        currentOriginalText = selectedText
        streamingClient.cancel()
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
                    guard let self, self.currentRequestAttemptID == requestAttemptID else { return }
                    self.resultPanel.update(
                        snapshot: TranslationModePresentation.snapshot(snapshot, mode: correctionMode),
                        originalText: selectedText,
                        settings: self.settings
                    )
                },
                onError: { [weak self] message, raw in
                    guard let self, self.currentRequestAttemptID == requestAttemptID else { return }
                    self.resultPanel.showError(message, raw: raw, originalText: selectedText, settings: self.settings)
                },
                onComplete: { [weak self] snapshot in
                    guard let self, self.currentRequestAttemptID == requestAttemptID else { return }
                    let presented = TranslationModePresentation.snapshot(snapshot, mode: correctionMode)
                    self.resultPanel.update(snapshot: presented, originalText: selectedText, settings: self.settings)
                    if let text = ResultPresentationPolicy.autoClipboardText(for: presented) {
                        self.clipboard.copy(text)
                    }
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
                    self?.rebuildMenu()
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
        guard selectionMouseDownMonitor == nil, selectionMouseUpMonitor == nil else {
            return
        }
        selectionMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.selectionMouseDownLocation = NSEvent.mouseLocation
        }
        selectionMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self else {
                return
            }
            let mouse = NSEvent.mouseLocation
            let mouseDragDistance = self.mouseDragDistance(to: mouse)
            guard !self.selectionHotZone.contains(point: mouse) else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.updateSelectionHotZone(near: mouse, mouseDragDistance: mouseDragDistance)
            }
        }
    }

    private func updateSelectionHotZone(near mouse: CGPoint, mouseDragDistance: Double?) {
        selectionClipboardFallbackToken += 1
        let fallbackToken = selectionClipboardFallbackToken
        let trusted = accessibility.isTrusted(prompt: false)
        let selectedText = trusted ? accessibility.selectedText() : nil
        let ownBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.zhixing.sayflow"
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let decision = SelectionHotZonePolicy.decision(
            accessibilityTrusted: trusted,
            selectedText: selectedText,
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            ownBundleIdentifier: ownBundleIdentifier
        )
        switch decision {
        case .show(let text):
            selectionHotZone.show(near: mouse, selectedText: text)
        case .hide:
            let fallbackAction = SelectionHotZoneClipboardFallbackPolicy.action(
                accessibilityTrusted: trusted,
                selectedText: selectedText,
                frontmostBundleIdentifier: frontmostBundleIdentifier,
                ownBundleIdentifier: ownBundleIdentifier,
                mouseDragDistance: mouseDragDistance
            )
            guard fallbackAction == .tryCopyShortcut else {
                selectionHotZone.hide()
                return
            }
            let previousClipboardChangeCount = clipboard.changeCount
            guard accessibility.copyFocusedSelectionToClipboard() else {
                selectionHotZone.hide()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
                self?.updateSelectionHotZoneFromClipboardFallback(
                    near: mouse,
                    previousClipboardChangeCount: previousClipboardChangeCount,
                    frontmostBundleIdentifier: frontmostBundleIdentifier,
                    fallbackToken: fallbackToken
                )
            }
        }
    }

    private func updateSelectionHotZoneFromClipboardFallback(
        near mouse: CGPoint,
        previousClipboardChangeCount: Int,
        frontmostBundleIdentifier: String?,
        fallbackToken: Int
    ) {
        guard fallbackToken == selectionClipboardFallbackToken else {
            return
        }
        guard clipboard.changeCount != previousClipboardChangeCount else {
            selectionHotZone.hide()
            return
        }
        let decision = SelectionHotZonePolicy.decision(
            accessibilityTrusted: accessibility.isTrusted(prompt: false),
            selectedText: clipboard.currentString(),
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            ownBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.zhixing.sayflow"
        )
        switch decision {
        case .show(let text):
            selectionHotZone.show(near: mouse, selectedText: text)
        case .hide:
            selectionHotZone.hide()
        }
    }

    private func mouseDragDistance(to mouse: CGPoint) -> Double? {
        guard let down = selectionMouseDownLocation else {
            return nil
        }
        let x = Double(mouse.x - down.x)
        let y = Double(mouse.y - down.y)
        return (x * x + y * y).squareRoot()
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
