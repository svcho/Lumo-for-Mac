import AppKit
import SwiftUI
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    var settings = AppSettings()
    private(set) var windows: [ChatWindowController] = []

    // MARK: – Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If SwiftUI launched a default window, close it — we create our own.
        for window in NSApplication.shared.windows {
            if window.contentViewController is NSHostingController<SettingsView> {
                continue
            }
            window.close()
        }

        openChatWindow()

        // Install native menu items.
        MenuBuilder.installMainMenu(target: self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: – Window management

    @discardableResult
    func openChatWindow(url: URL? = nil) -> ChatWindowController {
        let controller = ChatWindowController(settings: settings, urlString: url?.absoluteString)
        controller.showWindow(nil)
        windows.append(controller)
        return controller
    }

    func closeAllWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }

    // MARK: – Menu actions

    @objc func newWindow() {
        openChatWindow()
    }

    @objc func reload(_ sender: Any?) {
        activeWebViewController()?.reload()
    }

    @objc func goBack(_ sender: Any?) {
        activeWebViewController()?.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        activeWebViewController()?.goForward()
    }

    @objc func zoomIn(_ sender: Any?) {
        activeWebViewController()?.zoomIn()
    }

    @objc func zoomOut(_ sender: Any?) {
        activeWebViewController()?.zoomOut()
    }

    @objc func resetZoom(_ sender: Any?) {
        activeWebViewController()?.resetZoom()
    }

    @objc func find(_ sender: Any?) {
        activeWebViewController()?.showFindBar()
    }

    @objc func toggleSidebar(_ sender: Any?) {
        activeWebViewController()?.toggleSidebar()
    }

    @objc func focusMessageInput(_ sender: Any?) {
        activeWebViewController()?.focusMessageInput()
    }

    @objc func newChat(_ sender: Any?) {
        activeWebViewController()?.startNewChat()
    }

    @objc func clearCookies(_ sender: Any?) {
        guard let vc = activeWebViewController() else { return }
        vc.clearWebsiteData {
            vc.reload()
        }
    }

    @objc func showSettings() {
        // Open the SwiftUI Settings scene — works on macOS 12+
        NSApplication.shared.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    @objc func openAbout() {
        let alert = NSAlert()
        alert.messageText = "Lumo"
        alert.informativeText = "A native macOS client for Proton Lumo AI.\n\nWraps lumo.proton.me with native window chrome, persistent sessions, and performance optimizations.\n\nNot affiliated with Proton AG."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: – Helpers

    private func activeWebViewController() -> WebViewController? {
        guard let window = NSApplication.shared.keyWindow,
              let controller = window.windowController as? ChatWindowController else {
            return windows.first?.webViewController
        }
        return controller.webViewController
    }

    func windowControllerDidClose(_ controller: ChatWindowController) {
        windows.removeAll { $0 === controller }
    }
}

// MARK: – NSUserInterfaceItemValidation

extension AppDelegate {
    @objc func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let vc = activeWebViewController() else { return false }

        switch item.action {
        case #selector(goBack(_:)):
            return vc.webView.canGoBack
        case #selector(goForward(_:)):
            return vc.webView.canGoForward
        default:
            return true
        }
    }
}