import AppKit

enum StandardEditMenu {
    static func install() {
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem())
        mainMenu.addItem(editMenuItem())
        NSApp.mainMenu = mainMenu
    }

    private static func appMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let menu = NSMenu(title: "SayFlow")
        menu.addItem(NSMenuItem(title: "Quit SayFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menuItem.submenu = menu
        return menuItem
    }

    private static func editMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", action: "undo:", keyEquivalent: "z"))

        let redo = item("Redo", action: "redo:", keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)

        menu.addItem(.separator())
        menu.addItem(item("Cut", action: "cut:", keyEquivalent: "x"))
        menu.addItem(item("Copy", action: "copy:", keyEquivalent: "c"))
        menu.addItem(item("Paste", action: "paste:", keyEquivalent: "v"))
        menu.addItem(item("Delete", action: "delete:", keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(item("Select All", action: "selectAll:", keyEquivalent: "a"))
        menuItem.submenu = menu
        return menuItem
    }

    private static func item(_ title: String, action: String, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector(action), keyEquivalent: keyEquivalent)
        item.target = nil
        return item
    }
}
