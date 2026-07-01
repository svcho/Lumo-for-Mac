import AppKit

/// Builds a complete, native macOS menu bar for the app.
enum MenuBuilder {

    static func installMainMenu(target: AppDelegate) {
        let app = NSApp!

        let mainMenu = NSMenu()

        // ── App Menu ──
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Lumo", action: #selector(target.openAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(target.showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        let servicesMenu = NSMenu()
        let servicesItem = appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesMenu
        app.servicesMenu = servicesMenu
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Lumo", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Lumo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // ── File Menu ──
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Window", action: #selector(target.newWindow), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "New Chat", action: #selector(target.newChat(_:)), keyEquivalent: "t")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(NSMenuItem.separator())
        let clearItem = fileMenu.addItem(withTitle: "Clear Session & Reload", action: #selector(target.clearCookies(_:)), keyEquivalent: "r")
        clearItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // ── Edit Menu ──
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let pasteSpecial = editMenu.addItem(withTitle: "Paste and Match Style",
                                             action: Selector(("pasteAsPlainText:")), keyEquivalent: "v")
        pasteSpecial.keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find…", action: #selector(target.find(_:)), keyEquivalent: "f")
        editMenu.addItem(NSMenuItem.separator())

        let spellItem = editMenu.addItem(withTitle: "Spelling and Grammar", action: nil, keyEquivalent: "")
        let spellSubmenu = NSMenu(title: "Spelling and Grammar")
        spellSubmenu.addItem(withTitle: "Show Spelling and Grammar",
                             action: #selector(NSText.showGuessPanel(_:)), keyEquivalent: ":")
        spellSubmenu.addItem(withTitle: "Check Document Now",
                             action: #selector(NSText.checkSpelling(_:)), keyEquivalent: ";")
        spellItem.submenu = spellSubmenu
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // ── View Menu ──
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let sidebarItem = viewMenu.addItem(withTitle: "Toggle Sidebar", action: #selector(target.toggleSidebar(_:)),
                                           keyEquivalent: "s")
        sidebarItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(withTitle: "Focus Message Input", action: #selector(target.focusMessageInput(_:)), keyEquivalent: "l")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(target.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(target.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(target.resetZoom(_:)), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        let fullscreenItem = viewMenu.addItem(withTitle: "Enter Full Screen",
                                              action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullscreenItem.keyEquivalentModifierMask = [.command, .control]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // ── Navigate Menu ──
        let navMenuItem = NSMenuItem()
        let navMenu = NSMenu(title: "Navigate")
        navMenu.addItem(withTitle: "Back", action: #selector(target.goBack(_:)), keyEquivalent: "[")
        navMenu.addItem(withTitle: "Forward", action: #selector(target.goForward(_:)), keyEquivalent: "]")
        navMenu.addItem(withTitle: "Reload Page", action: #selector(target.reload(_:)), keyEquivalent: "r")
        navMenuItem.submenu = navMenu
        mainMenu.addItem(navMenuItem)

        // ── Window Menu ──
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        app.windowsMenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // ── Help Menu ──
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Lumo Help", action: #selector(target.openAbout), keyEquivalent: "?")
        helpMenu.addItem(withTitle: "Proton Privacy Policy", action: #selector(PrivacyHelper.openPrivacyPolicy), keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        app.helpMenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        app.mainMenu = mainMenu
    }
}

/// Helper class for menu actions that require @objc.
final class PrivacyHelper: NSObject {
    @objc static func openPrivacyPolicy() {
        if let url = URL(string: "https://proton.me/legal/privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}