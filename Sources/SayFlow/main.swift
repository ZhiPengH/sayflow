import AppKit

let app = NSApplication.shared
StandardEditMenu.install()
let delegate = SayFlowAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
