import AppKit
import Foundation
import SayFlowCore
#if canImport(ServiceManagement)
import ServiceManagement
#endif

final class SettingsWindowController: NSWindowController, NSTextViewDelegate {
    private var settings: AppSettings
    private let settingsStore: AppSettingsStore
    private let providerSecrets: LocalEnvironmentSecretStore
    private let providerTestClient = ProviderConnectionTestClient()
    private let onSettingsChanged: (AppSettings) -> Void
    private let onTestRun: (String) -> Void

    private let providerPopup = NSPopUpButton()
    private let apiKeyField = NSSecureTextField()
    private let baseURLField = NSTextField()
    private let modelField = NSComboBox()
    private let temperatureField = NSTextField()
    private let providerTestButton = NSButton(title: L10n.tr(.testProvider), target: nil, action: nil)
    private let providerTestStatusLabel = NSTextField(labelWithString: "")
    private let systemPromptView = NSTextView()
    private let userPromptView = NSTextView()
    private let positionPopup = NSPopUpButton()
    private let obsidianPathField = NSTextField()
    private let obsidianTemplateView = NSTextView()
    private let hotKeyField = NSTextField()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: L10n.tr(.launchAtLogin), target: nil, action: nil)
    private let updateCheckButton = NSButton(checkboxWithTitle: L10n.tr(.autoCheckUpdates), target: nil, action: nil)
    private let timeoutField = NSTextField()
    private let timeZonePopup = NSPopUpButton()
    private let promptValidationLabel = NSTextField(labelWithString: "")
    private let promptSaveButton = NSButton(title: L10n.tr(.save), target: nil, action: nil)
    private let promptTestButton = NSButton(title: L10n.tr(.testRun), target: nil, action: nil)

    init(
        settings: AppSettings,
        settingsStore: AppSettingsStore,
        providerSecrets: LocalEnvironmentSecretStore,
        onSettingsChanged: @escaping (AppSettings) -> Void,
        onTestRun: @escaping (String) -> Void
    ) {
        self.settings = settings
        self.settingsStore = settingsStore
        self.providerSecrets = providerSecrets
        self.onSettingsChanged = onSettingsChanged
        self.onTestRun = onTestRun
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr(.settingsTitle)
        super.init(window: window)
        window.center()
        window.contentView = buildTabs()
        reloadControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(settings: AppSettings) {
        self.settings = settings
        reloadControls()
    }

    private func buildTabs() -> NSTabView {
        let tabs = NSTabView()
        tabs.addTabViewItem(tab(L10n.tr(.tabGeneral), view: generalView()))
        tabs.addTabViewItem(tab(L10n.tr(.tabProviders), view: providersView()))
        tabs.addTabViewItem(tab(L10n.tr(.tabPrompts), view: promptsView()))
        tabs.addTabViewItem(tab(L10n.tr(.tabDisplay), view: displayView()))
        tabs.addTabViewItem(tab(L10n.tr(.tabObsidian), view: obsidianView()))
        tabs.addTabViewItem(tab(L10n.tr(.tabAbout), view: aboutView()))
        return tabs
    }

    private func tab(_ title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }

    private func generalView() -> NSView {
        let stack = formStack()
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(toggleLaunchAtLogin(_:))
        hotKeyField.placeholderString = "⌃⌘S"
        let saveHotKey = NSButton(title: L10n.tr(.saveHotkey), target: self, action: #selector(saveHotKey))
        timeoutField.placeholderString = "30"
        let saveTimeout = NSButton(title: L10n.tr(.saveTimeout), target: self, action: #selector(saveTimeout))
        updateCheckButton.target = self
        updateCheckButton.action = #selector(toggleUpdateCheck(_:))
        stack.addArrangedSubview(launchAtLoginButton)
        stack.addArrangedSubview(updateCheckButton)
        stack.addArrangedSubview(labeled(L10n.tr(.globalShortcut), field: hotKeyField, trailing: saveHotKey))
        stack.addArrangedSubview(labeled(L10n.tr(.networkTimeout), field: timeoutField, trailing: saveTimeout))
        return padded(stack)
    }

    private func providersView() -> NSView {
        let stack = formStack()
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        let save = NSButton(title: L10n.tr(.saveProvider), target: self, action: #selector(saveProvider))
        providerTestButton.target = self
        providerTestButton.action = #selector(testProvider)
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(providerTestButton)
        buttons.addArrangedSubview(save)
        providerTestStatusLabel.textColor = .secondaryLabelColor
        providerTestStatusLabel.isHidden = true
        stack.addArrangedSubview(labeled(L10n.tr(.activeProvider), field: providerPopup))
        stack.addArrangedSubview(labeled(L10n.tr(.apiKey), field: apiKeyField))
        stack.addArrangedSubview(labeled(L10n.tr(.baseURLEndpoint), field: baseURLField))
        stack.addArrangedSubview(labeled(L10n.tr(.model), field: modelField))
        stack.addArrangedSubview(labeled(L10n.tr(.temperature), field: temperatureField))
        stack.addArrangedSubview(providerTestStatusLabel)
        stack.addArrangedSubview(buttons)
        return padded(stack)
    }

    private func promptsView() -> NSView {
        let stack = formStack()
        configureEditor(systemPromptView, height: 170)
        configureEditor(userPromptView, height: 80)
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        promptTestButton.target = self
        promptTestButton.action = #selector(testRun)
        promptSaveButton.target = self
        promptSaveButton.action = #selector(savePrompt)
        buttons.addArrangedSubview(promptTestButton)
        buttons.addArrangedSubview(promptSaveButton)
        buttons.addArrangedSubview(NSButton(title: L10n.tr(.restoreDefault), target: self, action: #selector(restorePrompt)))
        buttons.addArrangedSubview(NSButton(title: L10n.tr(.export), target: self, action: #selector(exportPrompt)))
        buttons.addArrangedSubview(NSButton(title: L10n.tr(.import), target: self, action: #selector(importPrompt)))
        let hint = NSTextField(labelWithString: L10n.tr(.consumesOneAPICall))
        hint.textColor = .secondaryLabelColor
        buttons.addArrangedSubview(hint)
        promptValidationLabel.textColor = .systemRed
        promptValidationLabel.isHidden = true
        stack.addArrangedSubview(label(L10n.tr(.systemPrompt)))
        stack.addArrangedSubview(systemPromptView.enclosingScrollView ?? scroll(for: systemPromptView, height: 170))
        stack.addArrangedSubview(label(L10n.tr(.userPrompt)))
        stack.addArrangedSubview(userPromptView.enclosingScrollView ?? scroll(for: userPromptView, height: 80))
        stack.addArrangedSubview(promptValidationLabel)
        stack.addArrangedSubview(buttons)
        return padded(stack)
    }

    private func displayView() -> NSView {
        let stack = formStack()
        PopupPositionStrategy.allCases.forEach { strategy in
            positionPopup.addItem(withTitle: title(for: strategy))
            positionPopup.lastItem?.representedObject = strategy.rawValue
        }
        positionPopup.target = self
        positionPopup.action = #selector(saveDisplay)
        stack.addArrangedSubview(labeled(L10n.tr(.popupPosition), field: positionPopup))
        return padded(stack)
    }

    private func obsidianView() -> NSView {
        let stack = formStack()
        let choose = NSButton(title: L10n.tr(.chooseMarkdown), target: self, action: #selector(chooseObsidianFile))
        timeZonePopup.addItems(withTitles: [L10n.tr(.systemTimeZone), TimeZone.current.identifier, "Asia/Shanghai", "UTC", "America/Los_Angeles", "Europe/London"])
        configureEditor(obsidianTemplateView, height: 260)
        let save = NSButton(title: L10n.tr(.saveObsidianSettings), target: self, action: #selector(saveObsidian))
        stack.addArrangedSubview(labeled(L10n.tr(.targetMarkdownFile), field: obsidianPathField, trailing: choose))
        stack.addArrangedSubview(labeled(L10n.tr(.timeZone), field: timeZonePopup))
        stack.addArrangedSubview(label(L10n.tr(.writeTemplate)))
        stack.addArrangedSubview(obsidianTemplateView.enclosingScrollView ?? scroll(for: obsidianTemplateView, height: 260))
        stack.addArrangedSubview(save)
        return padded(stack)
    }

    private func aboutView() -> NSView {
        let stack = formStack()
        stack.addArrangedSubview(label(L10n.tr(.aboutName)))
        stack.addArrangedSubview(label(L10n.tr(.aboutVersion)))
        stack.addArrangedSubview(label(L10n.tr(.aboutReleases)))
        stack.addArrangedSubview(label(L10n.tr(.aboutShaNote)))
        return padded(stack)
    }

    private func reloadControls() {
        providerPopup.removeAllItems()
        providerPopup.addItems(withTitles: settings.providers.map(\.displayName))
        if let index = settings.providers.firstIndex(where: \.isActive) {
            providerPopup.selectItem(at: index)
            loadProvider(index: index)
        }
        hotKeyField.stringValue = settings.general.hotKey.displayText
        launchAtLoginButton.state = settings.general.launchAtLogin ? .on : .off
        updateCheckButton.state = settings.general.automaticallyChecksForUpdates ? .on : .off
        timeoutField.stringValue = String(settings.general.networkTimeoutSeconds)
        systemPromptView.string = settings.prompts.system
        userPromptView.string = settings.prompts.user
        updatePromptValidationState()
        select(positionPopup, representedValue: settings.display.positionStrategy.rawValue)
        obsidianPathField.stringValue = settings.obsidian.targetMarkdownPath ?? ""
        timeZonePopup.selectItem(withTitle: settings.obsidian.timeZoneIdentifier ?? L10n.tr(.systemTimeZone))
        obsidianTemplateView.string = settings.obsidian.writeTemplate.markdown
    }

    private func loadProvider(index: Int) {
        guard settings.providers.indices.contains(index) else {
            return
        }
        let provider = settings.providers[index]
        apiKeyField.stringValue = providerSecrets.read(reference: provider.apiKeyReference) ?? ""
        baseURLField.stringValue = provider.baseURL
        reloadModelOptions(for: provider)
        modelField.stringValue = provider.model
        temperatureField.stringValue = String(provider.temperature)
    }

    private func reloadModelOptions(for provider: ProviderConfiguration) {
        modelField.removeAllItems()
        let recommendedModels = ProviderModelOptions.recommendedModels(for: provider.kind)
        modelField.addItems(withObjectValues: recommendedModels)
        modelField.completes = !recommendedModels.isEmpty
        modelField.isEditable = true
    }

    private func persist() {
        do {
            try settingsStore.save(settings)
            onSettingsChanged(settings)
        } catch {
            showAlert(L10n.tr(.failedSaveSettings), error.localizedDescription)
        }
    }

    @objc private func providerChanged() {
        loadProvider(index: providerPopup.indexOfSelectedItem)
    }

    @objc private func saveProvider() {
        let index = providerPopup.indexOfSelectedItem
        guard var provider = providerFromEditors(index: index) else {
            return
        }
        for idx in settings.providers.indices {
            settings.providers[idx].isActive = idx == index
        }
        provider.isActive = true
        switch ProviderSettingsValidator.validate(provider) {
        case .valid:
            break
        case .invalid(let error):
            showAlert(L10n.tr(.invalidProviderTitle), providerSettingsMessage(for: error))
            return
        }
        settings.providers[index] = provider
        do {
            try providerSecrets.save(apiKeyField.stringValue, reference: settings.providers[index].apiKeyReference)
            persist()
        } catch {
            showAlert(L10n.tr(.failedSaveAPIKey), error.localizedDescription)
        }
    }

    @objc private func testProvider() {
        let index = providerPopup.indexOfSelectedItem
        guard let provider = providerFromEditors(index: index) else {
            return
        }
        switch ProviderSettingsValidator.validate(provider) {
        case .valid:
            break
        case .invalid(let error):
            showProviderTestStatus(
                String(format: L10n.tr(.providerTestFailedFormat), providerSettingsMessage(for: error)),
                color: .systemRed
            )
            return
        }
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            showProviderTestStatus(
                String(format: L10n.tr(.providerTestFailedFormat), L10n.tr(.missingAPIKey)),
                color: .systemRed
            )
            return
        }
        do {
            let endpoint = try EndpointNormalizer.openAIEndpoint(from: provider.baseURL)
            let request = try ProviderConnectionTestRequestFactory.makeRequest(
                configuration: provider,
                apiKey: apiKey,
                timeout: TimeInterval(settings.general.networkTimeoutSeconds),
                prompt: settings.prompts
            )
            providerTestButton.isEnabled = false
            showProviderTestStatus(L10n.tr(.providerTestInProgress), color: .secondaryLabelColor)
            providerTestClient.test(request: request) { [weak self] result in
                guard let self else { return }
                self.providerTestButton.isEnabled = true
                switch result {
                case .success(let statusCode):
                    self.showProviderTestStatus(
                        String(format: L10n.tr(.providerTestSucceededFormat), endpoint.kind.rawValue, statusCode),
                        color: .systemGreen
                    )
                case .failure(let error):
                    self.showProviderTestStatus(
                        String(format: L10n.tr(.providerTestFailedFormat), error.message),
                        color: .systemRed
                    )
                }
            }
        } catch {
            showProviderTestStatus(
                String(format: L10n.tr(.providerTestFailedFormat), error.localizedDescription),
                color: .systemRed
            )
        }
    }

    private func providerFromEditors(index: Int) -> ProviderConfiguration? {
        guard settings.providers.indices.contains(index) else {
            return nil
        }
        var provider = settings.providers[index]
        provider.baseURL = baseURLField.stringValue
        provider.model = modelField.stringValue
        provider.temperature = Double(temperatureField.stringValue) ?? 0.2
        return provider
    }

    private func showProviderTestStatus(_ message: String, color: NSColor) {
        providerTestStatusLabel.stringValue = message
        providerTestStatusLabel.textColor = color
        providerTestStatusLabel.isHidden = false
    }

    @objc private func saveHotKey() {
        guard let parsed = HotKeyParser.parse(hotKeyField.stringValue) else {
            showAlert(L10n.tr(.invalidHotkeyTitle), L10n.tr(.invalidHotkeyMessage))
            return
        }
        settings.general.hotKey = parsed
        persist()
    }

    @objc private func saveTimeout() {
        let value = Int(timeoutField.stringValue) ?? 30
        settings.general.networkTimeoutSeconds = min(max(value, 5), 120)
        timeoutField.stringValue = String(settings.general.networkTimeoutSeconds)
        persist()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let previous = settings.general.launchAtLogin
        let requested = sender.state == .on
        let succeeded = applyLaunchAtLogin(enabled: requested)
        settings.general.launchAtLogin = LaunchAtLoginTogglePolicy.resolvedSetting(
            requested: requested,
            previous: previous,
            systemChangeSucceeded: succeeded
        )
        sender.state = settings.general.launchAtLogin ? .on : .off
        persist()
    }

    @objc private func toggleUpdateCheck(_ sender: NSButton) {
        settings.general.automaticallyChecksForUpdates = sender.state == .on
        persist()
    }

    @objc private func saveDisplay() {
        if let rawValue = positionPopup.selectedItem?.representedObject as? String,
           let strategy = PopupPositionStrategy(rawValue: rawValue) {
            settings.display.positionStrategy = strategy
        }
        persist()
    }

    @objc private func testRun() {
        savePromptFromEditors(runAfterSave: true)
    }

    @objc private func savePrompt() {
        savePromptFromEditors(runAfterSave: false)
    }

    @objc private func restorePrompt() {
        settings.prompts = .defaultGrammarCorrection
        reloadControls()
        persist()
    }

    @objc private func exportPrompt() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "prompts.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try JSONEncoder().encode(settings.prompts)
                try data.write(to: url)
            } catch {
                showAlert(L10n.tr(.exportFailed), error.localizedDescription)
            }
        }
    }

    @objc private func importPrompt() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                settings.prompts = try PromptTemplateImportPolicy.decodeValidated(from: data)
                reloadControls()
                persist()
            } catch {
                showAlert(L10n.tr(.importFailed), error.localizedDescription)
            }
        }
    }

    @objc private func chooseObsidianFile() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["md"]
        panel.nameFieldStringValue = "SayFlow-Inbox.md"
        if panel.runModal() == .OK, let url = panel.url {
            obsidianPathField.stringValue = url.path
            saveObsidian()
        }
    }

    @objc private func saveObsidian() {
        let rawPath = obsidianPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawPath.isEmpty {
            settings.obsidian.targetMarkdownPath = nil
        } else {
            switch ObsidianTargetPathValidator.validate(rawPath) {
            case .valid(let url):
                settings.obsidian.targetMarkdownPath = url.path
                obsidianPathField.stringValue = url.path
            case .invalid(let error):
                showAlert(L10n.tr(.invalidObsidianPathTitle), obsidianPathMessage(for: error))
                return
            }
        }
        let selectedTimeZone = timeZonePopup.titleOfSelectedItem
        settings.obsidian.timeZoneIdentifier = selectedTimeZone == L10n.tr(.systemTimeZone) ? nil : selectedTimeZone
        settings.obsidian.writeTemplate = ObsidianTemplate(markdown: obsidianTemplateView.string)
        persist()
    }

    private func obsidianPathMessage(for error: ObsidianTargetPathValidationError) -> String {
        switch error {
        case .empty:
            return L10n.tr(.invalidObsidianPathEmpty)
        case .relativePath:
            return L10n.tr(.invalidObsidianPathRelative)
        case .notMarkdown:
            return L10n.tr(.invalidObsidianPathNotMarkdown)
        }
    }

    private func providerSettingsMessage(for error: ProviderSettingsValidationError) -> String {
        switch error {
        case .baseURL:
            return L10n.tr(.invalidProviderBaseURL)
        case .model:
            return L10n.tr(.invalidProviderModel)
        }
    }

    private func savePromptFromEditors(runAfterSave: Bool) {
        let template = PromptTemplate(system: systemPromptView.string, user: userPromptView.string)
        switch PromptTemplateValidator.validate(template) {
        case .valid:
            settings.prompts = template
            persist()
            if runAfterSave {
                onTestRun("The market are unpredictable in short-term.")
            }
        case .invalid(let message):
            promptValidationLabel.stringValue = message
            promptValidationLabel.isHidden = false
            promptSaveButton.isEnabled = false
            promptTestButton.isEnabled = false
        }
    }

    func textDidChange(_ notification: Notification) {
        updatePromptValidationState()
    }

    private func updatePromptValidationState() {
        let template = PromptTemplate(system: systemPromptView.string, user: userPromptView.string)
        switch PromptTemplateValidator.validate(template) {
        case .valid:
            promptValidationLabel.stringValue = ""
            promptValidationLabel.isHidden = true
            promptSaveButton.isEnabled = true
            promptTestButton.isEnabled = true
        case .invalid(let message):
            promptValidationLabel.stringValue = message
            promptValidationLabel.isHidden = false
            promptSaveButton.isEnabled = false
            promptTestButton.isEnabled = false
        }
    }

    private func title(for strategy: PopupPositionStrategy) -> String {
        switch strategy {
        case .followMouse:
            return L10n.tr(.followMouse)
        case .bottomLeft:
            return L10n.tr(.bottomLeft)
        case .center:
            return L10n.tr(.center)
        case .lastClosed:
            return L10n.tr(.lastClosed)
        }
    }

    private func select(_ popup: NSPopUpButton, representedValue: String) {
        guard let item = popup.itemArray.first(where: { $0.representedObject as? String == representedValue }) else {
            return
        }
        popup.select(item)
    }

    private func formStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        return stack
    }

    private func padded(_ view: NSView) -> NSView {
        let container = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            view.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])
        return container
    }

    private func labeled(_ title: String, field: NSView, trailing: NSView? = nil) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(field)
        if let trailing {
            row.addArrangedSubview(trailing)
        }
        return row
    }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.maximumNumberOfLines = 0
        return label
    }

    private func configureEditor(_ textView: NSTextView, height: CGFloat) {
        textView.font = NSFont(name: "Menlo", size: 12) ?? NSFont.userFixedPitchFont(ofSize: 12)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = self
        _ = scroll(for: textView, height: height)
    }

    private func scroll(for textView: NSTextView, height: CGFloat) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 650).isActive = true
        return scroll
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func applyLaunchAtLogin(enabled: Bool) -> Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                showAlert(L10n.tr(.launchAtLoginFailed), error.localizedDescription)
                return false
            }
        }
        #endif
        return false
    }
}
