import AppKit

enum SettingsTextEditorScrollView {
    static let width: CGFloat = 650

    static func make(for textView: NSTextView, height: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        textView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        scrollView.heightAnchor.constraint(equalToConstant: height).isActive = true
        scrollView.widthAnchor.constraint(equalToConstant: width).isActive = true
        return scrollView
    }
}
