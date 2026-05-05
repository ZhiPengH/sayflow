import AppKit
import Foundation
import SayFlowCore

final class ResultPanelController: NSObject {
    private let panel: NSPanel
    private let contentView = ResultPanelView()
    private let positioner = PopupPositioner()
    private var outsideClickMonitor: Any?
    private var escapeMonitor: Any?

    var onCopy: ((String) -> Void)?
    var onInsert: ((String, String) -> Bool)?
    var onAccept: ((String) -> Bool)?
    var onWrite: ((GrammarCorrection) throws -> Void)?
    var onRetry: (() -> Void)?

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.contentView = contentView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        contentView.onClose = { [weak self] in self?.close() }
        contentView.onInsert = { [weak self] original, corrected in
            guard let self else {
                return
            }
            if self.onInsert?(original, corrected) ?? false {
                self.contentView.flashInsertSuccess()
            } else {
                self.contentView.showError(L10n.tr(.insertFailed), raw: nil, allowsRetry: false)
            }
        }
        contentView.onAccept = { [weak self] text in
            guard let self else {
                return
            }
            let action = AcceptReplacementFallback.action(replacementSucceeded: self.onAccept?(text) ?? false)
            switch action {
            case .showReplacedFeedback:
                self.contentView.flashAcceptSuccess()
            case .copyCorrectedToClipboardAndWarn:
                self.onCopy?(text)
                self.contentView.showError(L10n.tr(.acceptCopiedFallback), raw: nil, allowsRetry: false)
            }
        }
        contentView.onRetry = { [weak self] in self?.onRetry?() }
        contentView.onWrite = { [weak self] correction in
            do {
                try self?.onWrite?(correction)
                self?.contentView.flashWriteSuccess()
            } catch {
                self?.contentView.showError("\(L10n.tr(.writeFailedPrefix))\(ObsidianWriteErrorMessage.message(for: error))", raw: nil, allowsRetry: false)
            }
        }
    }

    func showLoading(originalText: String, settings: AppSettings) {
        contentView.apply(theme: settings.display.theme)
        contentView.showLoading(originalText: originalText)
        showPanel(originalText: originalText, settings: settings)
    }

    func update(snapshot: CorrectionSnapshot, originalText: String, settings: AppSettings) {
        contentView.apply(theme: settings.display.theme)
        contentView.render(snapshot: snapshot, originalText: originalText)
        showPanel(originalText: originalText, settings: settings)
    }

    func showError(_ message: String, raw: String?, originalText: String, settings: AppSettings) {
        contentView.apply(theme: settings.display.theme)
        contentView.showError(message, raw: raw, allowsRetry: true)
        showPanel(originalText: originalText, settings: settings)
    }

    func close() {
        if panel.isVisible {
            positioner.recordClosedFrame(panel.frame)
        }
        removeEventMonitors()
        panel.close()
    }

    private func showPanel(originalText: String, settings: AppSettings) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = contentView.fittingPanelSize(screenFrame: screenFrame)
        let frame = positioner.frame(
            strategy: settings.display.positionStrategy,
            mouse: mouse,
            panelSize: size,
            screenFrame: screenFrame,
            selectedText: originalText
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        installEventMonitors()
    }

    private func installEventMonitors() {
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self, self.panel.isVisible else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.close()
                }
            }
        }
        if escapeMonitor == nil {
            escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    self?.close()
                }
            }
        }
    }

    private func removeEventMonitors() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }
}

final class ResultPanelView: NSView, NSTextViewDelegate {
    private let root = NSStackView()
    private let headerLabel = NSTextField(labelWithString: "📌 \(L10n.tr(.appName))")
    private let closeButton = NSButton(title: "×", target: nil, action: nil)
    private let errorRow = NSStackView()
    private let errorLabel = NSTextField(labelWithString: "")
    private let retryButton = NSButton(title: L10n.tr(.retry), target: nil, action: nil)
    private let rawResponseButton = NSButton(title: "", target: nil, action: nil)
    private let rawResponseView = NSTextView()
    private let correctedView = NSTextView()
    private let glossLabel = NSTextField(labelWithString: "")
    private let goodCard = NSBox()
    private let goodLabel = NSTextField(labelWithString: "")
    private let writeButton = NSButton(title: "", target: nil, action: nil)
    private let insertButton = NSButton(title: "", target: nil, action: nil)
    private let acceptButton = NSButton(title: "✓ \(L10n.tr(.accept))", target: nil, action: nil)

    private var correction: GrammarCorrection?
    private var originalText = ""
    private var rawResponseDisclosure = RawResponseDisclosure()
    private var correctedHeightConstraint: NSLayoutConstraint?

    var onClose: (() -> Void)?
    var onInsert: ((String, String) -> Void)?
    var onAccept: ((String) -> Void)?
    var onWrite: ((GrammarCorrection) -> Void)?
    var onRetry: (() -> Void)?

    var fittingPanelSize: CGSize {
        fittingPanelSize(screenFrame: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900))
    }

    func fittingPanelSize(screenFrame: CGRect) -> CGSize {
        frame.size.width = ResultPanelLayoutMetrics.panelWidth
        applyWrappingConstraints()
        layoutSubtreeIfNeeded()
        return PopupPanelSizer.size(
            width: ResultPanelLayoutMetrics.panelWidth,
            contentHeight: root.fittingSize.height + 28,
            screenHeight: screenFrame.height
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1).cgColor
        layer?.cornerRadius = 12
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: -6)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(theme: DisplayTheme) {
        appearance = NSAppearance(named: .aqua)
        layer?.backgroundColor = NSColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1).cgColor
    }

    func showLoading(originalText: String) {
        self.originalText = originalText
        headerLabel.stringValue = "📌 \(L10n.tr(.appName))     \(Self.preview(originalText))"
        errorRow.isHidden = true
        updateRawResponse(nil)
        glossLabel.stringValue = ""
        goodCard.isHidden = true
        correctedView.string = L10n.tr(.checkingGrammar)
        correction = nil
        updateDynamicTextHeights()
    }

    func render(snapshot: CorrectionSnapshot, originalText: String) {
        self.originalText = originalText
        headerLabel.stringValue = "📌 \(L10n.tr(.appName))     \(Self.preview(originalText))"
        errorRow.isHidden = snapshot.parseError == nil
        if let parseError = snapshot.parseError {
            errorLabel.stringValue = parseError
            retryButton.isHidden = false
        }
        updateRawResponse(snapshot.parseError == nil ? nil : snapshot.rawResponse)

        if let corrected = snapshot.corrected {
            renderCorrected(corrected, changes: snapshot.changes ?? [])
        }
        glossLabel.stringValue = snapshot.translationZh.map { "│  \($0)" } ?? ""

        if let good = snapshot.goodToKnow, !good.isEmpty {
            goodLabel.stringValue = "💡 \(L10n.tr(.goodToKnow))\n\(good)"
            goodCard.isHidden = false
        } else {
            goodCard.isHidden = true
        }

        if let corrected = snapshot.corrected, let changes = snapshot.changes, let translation = snapshot.translationZh {
            correction = GrammarCorrection(
                corrected: corrected,
                changes: changes,
                translationZh: translation,
                goodToKnow: snapshot.goodToKnow
            )
        }
        updateDynamicTextHeights()
    }

    func showError(_ message: String, raw: String?, allowsRetry: Bool = true) {
        errorLabel.stringValue = message
        errorRow.isHidden = false
        retryButton.isHidden = !allowsRetry
        updateRawResponse(raw)
        updateDynamicTextHeights()
    }

    func flashWriteSuccess() {
        flash(button: writeButton, replacementTitle: "✓")
    }

    func flashInsertSuccess() {
        flash(button: insertButton, replacementTitle: "✓")
    }

    func flashAcceptSuccess() {
        flash(button: acceptButton, replacementTitle: "✓")
    }

    private func build() {
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 16, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])

        let header = NSStackView(views: [headerLabel, closeButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        headerLabel.font = .systemFont(ofSize: 13, weight: .medium)
        headerLabel.lineBreakMode = .byTruncatingTail
        closeButton.bezelStyle = .inline
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        root.addArrangedSubview(header)

        errorRow.orientation = .horizontal
        errorRow.alignment = .centerY
        errorRow.spacing = 8
        errorRow.isHidden = true
        errorLabel.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.28)
        errorLabel.textColor = .labelColor
        errorLabel.isBezeled = false
        errorLabel.isEditable = false
        errorLabel.drawsBackground = true
        retryButton.bezelStyle = .rounded
        retryButton.target = self
        retryButton.action = #selector(retryTapped)
        errorRow.addArrangedSubview(errorLabel)
        errorRow.addArrangedSubview(retryButton)
        root.addArrangedSubview(errorRow)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        let title = NSTextField(labelWithString: L10n.tr(.corrected))
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = NSColor.systemGreen
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(NSView())
        configureIconButton(writeButton, symbol: "square.and.pencil", fallback: L10n.tr(.writeFallback), tooltip: L10n.tr(.writeTooltip), action: #selector(writeTapped))
        configureIconButton(insertButton, symbol: "text.badge.plus", fallback: L10n.tr(.insertFallback), tooltip: L10n.tr(.insertTooltip), action: #selector(insertTapped))
        acceptButton.bezelStyle = .rounded
        acceptButton.target = self
        acceptButton.action = #selector(acceptTapped)
        titleRow.addArrangedSubview(writeButton)
        titleRow.addArrangedSubview(insertButton)
        titleRow.addArrangedSubview(acceptButton)
        root.addArrangedSubview(titleRow)

        correctedView.isEditable = false
        correctedView.isSelectable = true
        correctedView.drawsBackground = false
        correctedView.delegate = self
        correctedView.font = .systemFont(ofSize: 18)
        correctedView.isHorizontallyResizable = false
        correctedView.textContainer?.widthTracksTextView = true
        correctedView.textContainer?.lineFragmentPadding = 0
        correctedView.textContainerInset = NSSize(width: 0, height: 0)
        correctedView.linkTextAttributes = [
            .foregroundColor: NSColor.labelColor,
            .underlineStyle: 0
        ]
        correctedView.isVerticallyResizable = false
        correctedView.textContainer?.heightTracksTextView = false
        let correctedHeightConstraint = correctedView.heightAnchor.constraint(equalToConstant: 44)
        correctedHeightConstraint.isActive = true
        self.correctedHeightConstraint = correctedHeightConstraint
        root.addArrangedSubview(correctedView)

        glossLabel.font = .systemFont(ofSize: 13)
        glossLabel.textColor = .secondaryLabelColor
        glossLabel.maximumNumberOfLines = 0
        glossLabel.lineBreakMode = .byWordWrapping
        root.addArrangedSubview(glossLabel)

        goodCard.boxType = .custom
        goodCard.cornerRadius = 8
        goodCard.borderWidth = 0
        goodCard.fillColor = NSColor(red: 0.98, green: 0.90, blue: 0.70, alpha: 0.62)
        goodLabel.font = .systemFont(ofSize: 13)
        goodLabel.textColor = NSColor.brown
        goodLabel.maximumNumberOfLines = 0
        goodLabel.lineBreakMode = .byWordWrapping
        goodLabel.translatesAutoresizingMaskIntoConstraints = false
        goodCard.contentView?.addSubview(goodLabel)
        if let contentView = goodCard.contentView {
            NSLayoutConstraint.activate([
                goodLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                goodLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                goodLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
                goodLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
            ])
        }
        goodCard.isHidden = true
        root.addArrangedSubview(goodCard)

        rawResponseView.isEditable = false
        rawResponseView.isHidden = true
        rawResponseView.font = NSFont(name: "Menlo", size: 11) ?? NSFont.userFixedPitchFont(ofSize: 11)
        rawResponseView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        rawResponseButton.bezelStyle = .inline
        rawResponseButton.target = self
        rawResponseButton.action = #selector(toggleRawResponse)
        rawResponseButton.isHidden = true
        root.addArrangedSubview(rawResponseButton)
        root.addArrangedSubview(rawResponseView)
    }

    private func applyWrappingConstraints() {
        let contentTextWidth = ResultPanelLayoutMetrics.contentTextWidth
        let goodToKnowTextWidth = ResultPanelLayoutMetrics.goodToKnowTextWidth
        correctedView.textContainer?.containerSize = NSSize(width: contentTextWidth, height: CGFloat.greatestFiniteMagnitude)
        glossLabel.preferredMaxLayoutWidth = contentTextWidth
        goodLabel.preferredMaxLayoutWidth = goodToKnowTextWidth
    }

    private func updateDynamicTextHeights() {
        applyWrappingConstraints()
        guard let textContainer = correctedView.textContainer else {
            return
        }
        correctedView.layoutManager?.ensureLayout(for: textContainer)
        let usedHeight = correctedView.layoutManager?.usedRect(for: textContainer).height ?? 0
        correctedHeightConstraint?.constant = max(44, ceil(usedHeight + correctedView.textContainerInset.height * 2 + 2))
        glossLabel.invalidateIntrinsicContentSize()
        goodLabel.invalidateIntrinsicContentSize()
        layoutSubtreeIfNeeded()
    }

    private func updateRawResponse(_ raw: String?) {
        rawResponseDisclosure.setRawResponse(raw)
        rawResponseButton.isHidden = !rawResponseDisclosure.hasRawResponse
        rawResponseButton.title = rawResponseDisclosure.isExpanded
            ? "▾ \(L10n.tr(.rawResponse))"
            : "▸ \(L10n.tr(.rawResponse))"
        rawResponseView.string = rawResponseDisclosure.visibleRawResponse ?? ""
        rawResponseView.isHidden = rawResponseDisclosure.visibleRawResponse == nil
    }

    private func renderCorrected(_ corrected: String, changes: [GrammarChange]) {
        let attributed = NSMutableAttributedString(
            string: corrected,
            attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.labelColor
            ]
        )
        for range in DiffPillLocator.ranges(in: corrected, changes: changes) {
            attributed.addAttributes([
                .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.25),
                .link: URL(string: "sayflow-change://\(range.changeIndex)") as Any
            ], range: range.nsRange)
        }
        correctedView.textStorage?.setAttributedString(attributed)
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL,
              let index = Int(url.host ?? ""),
              let change = correction?.changes[safe: index] else {
            return false
        }
        let popover = NSPopover()
        popover.behavior = .transient
        let replaced = String(format: L10n.tr(.replacedChangeFormat), change.old, change.new)
        let label = NSTextField(labelWithString: "\(replaced)\n\(change.explain)")
        label.maximumNumberOfLines = 0
        label.frame = NSRect(x: 0, y: 0, width: 260, height: 86)
        let controller = NSViewController()
        controller.view = label
        popover.contentViewController = controller
        popover.show(relativeTo: textView.visibleRect, of: textView, preferredEdge: .maxY)
        return true
    }

    private func configureIconButton(_ button: NSButton, symbol: String, fallback: String, tooltip: String, action: Selector) {
        button.title = ""
        if #available(macOS 11.0, *) {
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
                button.image = image
            } else {
                button.title = fallback
            }
        } else {
            button.title = fallback
        }
        button.toolTip = tooltip
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = action
    }

    private func flash(button: NSButton, replacementTitle: String) {
        let oldTitle = button.title
        let oldAttributedTitle = button.attributedTitle
        let oldImage = button.image
        button.image = nil
        button.attributedTitle = NSAttributedString(
            string: replacementTitle,
            attributes: [
                .foregroundColor: NSColor.systemGreen,
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold)
            ]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            button.title = oldTitle
            button.attributedTitle = oldAttributedTitle
            button.image = oldImage
        }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func writeTapped() {
        guard let correction else {
            return
        }
        onWrite?(correction)
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func toggleRawResponse() {
        rawResponseDisclosure.toggle()
        rawResponseButton.title = rawResponseDisclosure.isExpanded
            ? "▾ \(L10n.tr(.rawResponse))"
            : "▸ \(L10n.tr(.rawResponse))"
        rawResponseView.string = rawResponseDisclosure.visibleRawResponse ?? ""
        rawResponseView.isHidden = rawResponseDisclosure.visibleRawResponse == nil
    }

    @objc private func insertTapped() {
        guard let correction else {
            return
        }
        onInsert?(originalText, correction.corrected)
    }

    @objc private func acceptTapped() {
        guard let correction else {
            return
        }
        onAccept?(correction.corrected)
    }

    private static func preview(_ text: String) -> String {
        if text.count <= 34 {
            return text
        }
        return String(text.prefix(34)) + "..."
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}
