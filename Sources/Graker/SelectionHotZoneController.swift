import AppKit
import GrakerCore

final class SelectionHotZoneController: NSObject {
    private let panel: NSPanel
    private let button = NSButton(title: "G", target: nil, action: nil)

    var onTrigger: (() -> Void)?

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 34, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        let lightAppearance = NSAppearance(named: .aqua)
        panel.appearance = lightAppearance
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        button.appearance = lightAppearance
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.toolTip = L10n.tr(.checkGrammar)
        button.target = self
        button.action = #selector(trigger)
        button.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 34, height: 30))
        container.appearance = lightAppearance
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 0.96).cgColor
        container.layer?.cornerRadius = 8
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.18
        container.layer?.shadowRadius = 8
        container.layer?.shadowOffset = CGSize(width: 0, height: -2)
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])
        panel.contentView = container
    }

    func show(near mouse: CGPoint, selectedText: String) {
        guard !selectedText.isEmpty else {
            hide()
            return
        }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrame(frame(near: mouse, screenFrame: screenFrame), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.close()
    }

    func contains(point: CGPoint) -> Bool {
        panel.isVisible && panel.frame.contains(point)
    }

    private func frame(near mouse: CGPoint, screenFrame: NSRect) -> NSRect {
        let size = CGSize(width: 34, height: 30)
        let inset: CGFloat = 8
        var origin = CGPoint(x: mouse.x + 10, y: mouse.y - size.height - 10)
        if origin.y < screenFrame.minY + inset {
            origin.y = mouse.y + 10
        }
        origin.x = min(max(origin.x, screenFrame.minX + inset), screenFrame.maxX - size.width - inset)
        origin.y = min(max(origin.y, screenFrame.minY + inset), screenFrame.maxY - size.height - inset)
        return NSRect(origin: origin, size: size)
    }

    @objc private func trigger() {
        hide()
        onTrigger?()
    }
}
