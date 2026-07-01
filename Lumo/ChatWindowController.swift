import AppKit
import WebKit

/// Controls a single chat window with native macOS chrome.
final class ChatWindowController: NSWindowController, NSWindowDelegate {

    let settings: AppSettings
    let webViewController: WebViewController

    init(settings: AppSettings, urlString: String? = nil) {
        self.settings = settings
        self.webViewController = WebViewController(settings: settings, urlString: urlString)

        let windowSize = NSSize(width: 1200, height: 780)
        let minSize = NSSize(width: 800, height: 500)

        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ]

        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: windowSize.width,
                height: windowSize.height
            ),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: .vibrantDark)
        window.minSize = minSize
        window.center()
        window.isReleasedWhenClosed = false

        // Toolbar for native feel.
        let toolbar = NSToolbar(identifier: "lumo.toolbar")
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar

        super.init(window: window)
        window.delegate = self
        window.contentViewController = webViewController

        // Set toolbar delegate after super.init since it references self.
        toolbar.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: – NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let app = NSApplication.shared.delegate as? AppDelegate else { return }
        app.windowControllerDidClose(self)
    }
}

// MARK: – NSToolbarDelegate

extension ChatWindowController: NSToolbarDelegate {

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .newChat,
            .back,
            .forward,
            .reload,
            .spacer,
            .sidebar,
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .newChat,
            .back,
            .forward,
            .reload,
            .flexibleSpace,
            .sidebar,
        ]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)

        switch identifier {
        case .newChat:
            item.label = "New Chat"
            item.paletteLabel = "New Chat"
            item.toolTip = "Start a new conversation"
            item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Chat")
            item.action = #selector(AppDelegate.newChat)
            item.target = NSApplication.shared.delegate
        case .back:
            item.label = "Back"
            item.paletteLabel = "Back"
            item.toolTip = "Navigate back"
            item.image = NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: "Back")
            item.action = #selector(AppDelegate.goBack(_:))
            item.target = NSApplication.shared.delegate
        case .forward:
            item.label = "Forward"
            item.paletteLabel = "Forward"
            item.toolTip = "Navigate forward"
            item.image = NSImage(systemSymbolName: "chevron.forward", accessibilityDescription: "Forward")
            item.action = #selector(AppDelegate.goForward(_:))
            item.target = NSApplication.shared.delegate
        case .reload:
            item.label = "Reload"
            item.paletteLabel = "Reload"
            item.toolTip = "Reload page"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
            item.action = #selector(AppDelegate.reload(_:))
            item.target = NSApplication.shared.delegate
        case .sidebar:
            item.label = "Sidebar"
            item.paletteLabel = "Toggle Sidebar"
            item.toolTip = "Toggle conversation sidebar"
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Sidebar")
            item.action = #selector(AppDelegate.toggleSidebar(_:))
            item.target = NSApplication.shared.delegate
        default:
            return nil
        }

        return item
    }
}

// MARK: – Custom Toolbar Item Identifiers

private extension NSToolbarItem.Identifier {
    static let newChat = NSToolbarItem.Identifier("lumo.newChat")
    static let back = NSToolbarItem.Identifier("lumo.back")
    static let forward = NSToolbarItem.Identifier("lumo.forward")
    static let reload = NSToolbarItem.Identifier("lumo.reload")
    static let sidebar = NSToolbarItem.Identifier("lumo.sidebar")
    static let spacer = NSToolbarItem.Identifier("lumo.spacer")
}