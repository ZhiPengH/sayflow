import AppKit

@main
enum SettingsTextEditorScrollViewTests {
    static func main() {
        let expectedHeight: CGFloat = 250
        let textView = NSTextView()

        let scrollView = SettingsTextEditorScrollView.make(for: textView, height: expectedHeight)
        textView.string = "Prompt text must have a usable layout width before deferred tab layout."

        guard textView.frame.width == SettingsTextEditorScrollView.width else {
            fail("expected text view width \(SettingsTextEditorScrollView.width), got \(textView.frame.width)")
        }
        guard textView.textContainer?.containerSize.width == SettingsTextEditorScrollView.width else {
            fail("text container did not inherit the initial editor width")
        }
        guard scrollView.documentView === textView else {
            fail("scroll view lost its text editor document view")
        }

        print("PASS settings text editors start with a usable layout width")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL \(message)\n".utf8))
        exit(1)
    }
}
