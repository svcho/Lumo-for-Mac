import AppKit
import Combine
import WebKit

private final class TitlebarDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// The main view controller hosting the WKWebView for Proton Lumo.
///
/// Key design decisions for native feel + performance:
///  • Uses the default (persistent) `WKWebsiteDataStore` so login cookies survive app restarts.
///  • Enables hardware-accelerated compositing & disables subframe spell-check overhead.
///  • Injects CSS/JS to blend the web UI with macOS chrome (vibrancy, dark mode).
///  • Handles external links by opening them in the system browser.
///  • Supports native keyboard shortcuts, find bar, zoom persistence.
final class WebViewController: NSViewController {

    // MARK: – Properties

    let settings: AppSettings
    private let urlString: String?
    private(set) var webView: WKWebView!
    private var findBar: NSSearchField?
    private var findBarHeightConstraint: NSLayoutConstraint?
    private var titlebarDragHeightConstraint: NSLayoutConstraint?
    private var titleObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var appearanceObserver: NSKeyValueObservation?
    private var settingsCancellables: Set<AnyCancellable> = []
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    private static let lumoURL = URL(string: "https://lumo.proton.me/")!

    // MARK: – Init

    init(settings: AppSettings, urlString: String? = nil) {
        self.settings = settings
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: – Lifecycle

    override func loadView() {
        let configuration = buildWebConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false

        // Performance & native feel tweaks.
        webView.wantsLayer = true
        webView.layer?.backgroundColor = .clear
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }

        // Navigation.
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Bind zoom from settings.
        applyZoom()

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.addSubview(webView)

        let titlebarDragView = TitlebarDragView()
        titlebarDragView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titlebarDragView)

        let titlebarDragHeightConstraint = titlebarDragView.heightAnchor.constraint(equalToConstant: 46)
        self.titlebarDragHeightConstraint = titlebarDragHeightConstraint

        NSLayoutConstraint.activate([
            // Pin to the container top (not the safe area) so the page extends
            // under the transparent titlebar/toolbar.
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titlebarDragView.topAnchor.constraint(equalTo: container.topAnchor),
            titlebarDragView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titlebarDragView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titlebarDragHeightConstraint,
        ])

        self.view = container

        // Navigate — use provided URL or default to Lumo.
        let targetURL = urlString.flatMap { URL(string: $0) } ?? Self.lumoURL
        webView.load(URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy))

        // Observe properties for UI updates.
        observeWebView()

        // Spell checking — toggle via WebKit preference.
        if !settings.enableSpellChecking {
            Self.setPrivatePreference(false, key: "spellCheckingEnabled", on: webView.configuration.preferences)
        }

        // Observe system appearance changes for theme syncing.
        // The observation must be retained or it is invalidated immediately.
        appearanceObserver = NSApp?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.systemAppearanceChanged()
            }
        }

        // Listen for page-ready notifications from the JS bridge.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pageReady(_:)),
            name: LumoMessageHandler.pageReadyNotification,
            object: nil
        )

        settings.$zoomLevel
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyZoom() }
            .store(in: &settingsCancellables)

        settings.$enableSpellChecking
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                Self.setPrivatePreference(enabled, key: "spellCheckingEnabled",
                                          on: self.webView.configuration.preferences)
            }
            .store(in: &settingsCancellables)
    }

    // MARK: – Private Preferences

    /// Sets a non-public WKPreferences key only if a setter for it still exists
    /// (public `set<Key>:` or KVC-reachable `_set<Key>:`), so a future WebKit
    /// that drops the key degrades to a no-op instead of crashing with
    /// NSUnknownKeyException.
    private static func setPrivatePreference(_ value: Any?, key: String, on preferences: WKPreferences) {
        let capitalized = key.prefix(1).uppercased() + key.dropFirst()
        let setter = Selector(("set\(capitalized):"))
        let privateSetter = Selector(("_set\(capitalized):"))
        guard preferences.responds(to: setter) || preferences.responds(to: privateSetter) else { return }
        preferences.setValue(value, forKey: key)
    }

    // MARK: – WebView Configuration

    private func buildWebConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // Persistent data store — keeps cookies, localStorage, session data.
        config.websiteDataStore = .default()

        // Preferences.
        let prefs = config.preferences
        prefs.javaScriptCanOpenWindowsAutomatically = false
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        // On macOS 13+ we can use webpage preferences for additional control.
        if #available(macOS 13.3, *) {
            config.preferences.shouldPrintBackgrounds = true
        }

        // Enable developer extras only in debug builds.
        #if DEBUG
        Self.setPrivatePreference(true, key: "developerExtrasEnabled", on: config.preferences)
        #endif

        // Inject user content controller for native bridge + styling.
        let ucc = WKUserContentController()
        injectNativeEnhancements(into: ucc)
        config.userContentController = ucc

        // Custom user agent — appends "Lumo/1.0" to the WebKit UA string
        // for site compatibility. When disabled, uses the default WebKit UA.
        if settings.customUserAgent {
            config.applicationNameForUserAgent = "Lumo/1.0"
        }

        // Allow local content & media.
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = false  // Stream content as it arrives.

        return config
    }

    // MARK: – JavaScript & CSS Injection

    private func injectNativeEnhancements(into ucc: WKUserContentController) {
        // CSS: Make the page blend with macOS native chrome.
        let css = """
        :root {
            --lumo-bg: transparent;
        }

        /* Remove any default white background to let vibrancy through. */
        html, body {
            background-color: transparent !important;
        }

        /* Reserve space for the native titlebar: Lumo lays out its sidebar and
           main area as rounded cards on a full-window backdrop, so padding the
           card container keeps the backdrop painting to the very top edge while
           the UI clears the traffic lights. The var is set from native code to
           match the real titlebar height. */
        .main-layout-component {
            padding-top: var(--lumo-native-titlebar, 38px) !important;
        }

        /* Pages without the card layout (e.g. the Proton account sign-in page)
           place their header/controls at the very top edge. Inset the whole
           page so those controls clear the transparent titlebar too. */
        body:not(:has(.main-layout-component)) {
            padding-top: var(--lumo-native-titlebar, 38px) !important;
        }

        /* Native-style focus rings. */
        *:focus-visible {
            outline: 2px solid -webkit-focus-ring-color !important;
            outline-offset: 2px;
        }

        /* Prevent text selection on UI chrome (native app feel). */
        .sidebar, .nav, .header, .toolbar, button[role="tab"] {
            -webkit-user-select: none;
            user-select: none;
        }

        /* Smooth font rendering. */
        body {
            -webkit-font-smoothing: antialiased;
            -webkit-text-size-adjust: 100%;
        }

        /* Custom thin scrollbar for webkit. */
        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        ::-webkit-scrollbar-track {
            background: transparent;
        }
        ::-webkit-scrollbar-thumb {
            background: rgba(128,128,128,0.4);
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: rgba(128,128,128,0.6);
        }

        /* Remove web context menu on long press for app-like feel. */
        img { -webkit-user-drag: none; }
        """

        let cssScript = WKUserScript(
            source: """
            (function() {
                var style = document.createElement('style');
                style.textContent = `\(css)`;
                (document.head || document.documentElement).appendChild(style);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        ucc.addUserScript(cssScript)

        // JS: Bridge for native features.
        let bridgeScript = WKUserScript(
            source: """
            (function() {
                window.LumoNative = {
                    // Called when page is ready.
                    ready: function() {
                        window.webkit.messageHandlers.lumoBridge.postMessage({type: 'ready', url: window.location.href});
                    },

                    // Focus the message input.
                    focusInput: function() {
                        var input = document.querySelector('textarea, [contenteditable="true"], input[type="text"]');
                        if (input) { input.focus(); }
                    },

                    // Toggle sidebar if a sidebar toggle button exists.
                    toggleSidebar: function() {
                        var btn = document.querySelector('[aria-label*="sidebar"], [aria-label*="Sidebar"], button[class*="sidebar"], button[class*="menu"]');
                        if (btn) { btn.click(); return true; }
                        return false;
                    },

                    // Start new chat.
                    newChat: function() {
                        var btn = document.querySelector('[aria-label*="new"], [aria-label*="New"], button[class*="new"]');
                        if (btn) { btn.click(); return true; }
                        return false;
                    },

                    // Detect dark/light mode.
                    getTheme: function() {
                        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
                    }
                };

                // Notify native when DOM is ready.
                if (document.readyState !== 'loading') {
                    window.LumoNative.ready();
                } else {
                    document.addEventListener('DOMContentLoaded', window.LumoNative.ready);
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        ucc.addUserScript(bridgeScript)

        // Register message handler.
        ucc.add(LumoMessageHandler.shared, name: "lumoBridge")
    }

    // MARK: – Observation

    private func observeWebView() {
        titleObserver = webView.observe(\.title, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                if let title = change.newValue ?? nil, !title.isEmpty {
                    self?.view.window?.title = title
                } else {
                    self?.view.window?.title = "Lumo"
                }
            }
        }

        urlObserver = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.applyZoom()
            }
        }
    }

    // MARK: – Theme Sync

    @objc private func systemAppearanceChanged() {
        // The window chrome is forced to .vibrantDark (see ChatWindowController),
        // so view.effectiveAppearance is always dark. Read the app/system
        // appearance so the web content follows the real Light/Dark setting.
        let appearance = NSApp?.effectiveAppearance ?? view.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = isDark ? "dark" : "light"

        webView.evaluateJavaScript("""
            (function() {
                document.documentElement.setAttribute('data-lumo-theme', '\(theme)');
                var media = window.matchMedia('(prefers-color-scheme: \(theme))');
                if (media.dispatchEvent) {
                    media.dispatchEvent(new MediaQueryListEvent('change', { media: media.media, matches: \(isDark) }));
                }
            })();
        """) { _, _ in }
    }

    @objc private func pageReady(_ notification: Notification) {
        systemAppearanceChanged()
        applyTitlebarInset()
    }

    /// Pushes the page's card layout below the native titlebar so the traffic
    /// lights don't overlap the web UI, while the page background still
    /// extends edge-to-edge behind them.
    private func applyTitlebarInset() {
        guard let window = view.window, let contentView = window.contentView else { return }
        let inset: CGFloat
        if let close = window.standardWindowButton(.closeButton), let bar = close.superview {
            // Pad to just below the traffic-light buttons rather than the full
            // titlebar height (which includes empty toolbar space).
            let frame = bar.convert(close.frame, to: nil)
            inset = window.frame.height - frame.minY + 10
        } else {
            inset = max(contentView.frame.height - window.contentLayoutRect.height, 28) + 8
        }
        webView.evaluateJavaScript(
            "document.documentElement.style.setProperty('--lumo-native-titlebar', '\(Int(inset))px')"
        ) { _, _ in }
        titlebarDragHeightConstraint?.constant = inset
    }

    // MARK: – Zoom

    func applyZoom() {
        webView.setMagnification(settings.zoomLevel, centeredAt: .zero)
    }

    func zoomIn() {
        settings.zoomLevel = min(settings.zoomLevel + 0.1, 3.0)
        applyZoom()
    }

    func zoomOut() {
        settings.zoomLevel = max(settings.zoomLevel - 0.1, 0.5)
        applyZoom()
    }

    func resetZoom() {
        settings.zoomLevel = 1.0
        applyZoom()
    }

    // MARK: – Navigation

    func reload() {
        webView.reload()
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    // MARK: – Native Actions

    func showFindBar() {
        guard findBar == nil else {
            findBar?.selectAll(nil)
            findBar?.window?.makeFirstResponder(findBar)
            return
        }

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Find on page…"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(findTextChanged(_:))

        bar.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: bar.topAnchor, constant: 6),
            searchField.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -6),
            searchField.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
        ])

        view.addSubview(bar)
        let heightConstraint = bar.heightAnchor.constraint(equalToConstant: 0)
        findBarHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,
        ])

        // Animate in.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            heightConstraint.animator().constant = 36
        }

        self.findBar = searchField
        view.window?.makeFirstResponder(searchField)
    }

    @objc private func findTextChanged(_ sender: NSSearchField) {
        let query = sender.stringValue
        guard !query.isEmpty else { return }
        // Use WebKit's built-in find. Pass the query as a JSON-encoded
        // string to safely handle quotes, backslashes, and special characters.
        guard let encodedData = try? JSONEncoder().encode(query),
              let encodedQuery = String(data: encodedData, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.find(\(encodedQuery))", completionHandler: nil)
    }

    func toggleSidebar() {
        webView.evaluateJavaScript("window.LumoNative && window.LumoNative.toggleSidebar()") { _, _ in }
    }

    func focusMessageInput() {
        webView.evaluateJavaScript("window.LumoNative && window.LumoNative.focusInput()") { _, _ in }
    }

    func startNewChat() {
        webView.evaluateJavaScript("window.LumoNative && window.LumoNative.newChat()") { result, _ in
            if let success = result as? Bool, !success {
                // Fallback: reload to root URL.
                self.webView.load(URLRequest(url: Self.lumoURL))
            }
        }
    }

    // MARK: – Cookie / Data Management

    func clearWebsiteData(completion: @escaping () -> Void) {
        let store = webView.configuration.websiteDataStore
        let dateFrom = Date(timeIntervalSince1970: 0)
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                         modifiedSince: dateFrom) {
            completion()
        }
    }
}

// MARK: – NSSearchFieldDelegate

extension WebViewController: NSSearchFieldDelegate {
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        // Remove find bar.
        if let bar = sender.superview {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                self.findBarHeightConstraint?.animator().constant = 0
            }) {
                bar.removeFromSuperview()
                self.findBar = nil
            }
        }
    }
}

// MARK: – WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let action = NavigationPolicy.decide(for: url, blockTrackers: settings.blockTrackers)
        switch action {
        case .allow:
            decisionHandler(.allow)
        case .openExternal:
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        case .cancel:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Could show a loading indicator.
        view.window?.title = "Loading…"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyZoom()
        systemAppearanceChanged()
        applyTitlebarInset()
        if let title = webView.title, !title.isEmpty {
            view.window?.title = title
        } else {
            view.window?.title = "Lumo"
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    private func handleLoadFailure(_ error: Error) {
        let nsError = error as NSError
        // Benign: superseded navigations and policy-cancelled/download-converted
        // frame loads. WebKitErrorDomain 102 = "Frame load interrupted".
        if nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }

        view.window?.title = "Lumo"
        let message: String
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            message = "You appear to be offline. Check your internet connection and try again."
        } else {
            message = "The page could not be loaded. \(nsError.localizedDescription)"
        }
        showOfflinePage(message: message)
    }

    // MARK: – Authentication Challenge

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Use default handling for TLS certs.
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: – Downloads

    func webView(_ webView: WKWebView, didStartDownload download: WKDownload) {
        download.delegate = self
    }

    // MARK: – Offline Page

    private func showOfflinePage(message: String) {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>
            body { font-family: -apple-system, system-ui, sans-serif; display:flex; align-items:center;
                   justify-content:center; height:100vh; margin:0; background:transparent; color: #e0e0e0; }
            .card { text-align:center; max-width:400px; padding:40px; }
            h1 { font-size:48px; margin-bottom:8px; opacity:0.3; }
            p { font-size:16px; opacity:0.6; line-height:1.5; }
            button { margin-top:20px; padding:10px 24px; font-size:14px; border:none;
                     border-radius:8px; background:#6366f1; color:white; cursor:pointer; }
        </style></head>
        <body><div class="card">
            <h1>🔌</h1>
            <p>\(escaped)</p>
            <button onclick="location.href='\(Self.lumoURL.absoluteString)'">Retry</button>
        </div></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: – WKUIDelegate

extension WebViewController: WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle window.open() — load in main view instead of a new window.
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        if panel.runModal() == .OK {
            completionHandler(panel.urls)
        } else {
            completionHandler(nil)
        }
    }
}

// MARK: – WKDownloadDelegate

extension WebViewController: WKDownloadDelegate {

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        if panel.runModal() == .OK, let url = panel.url {
            downloadDestinations[ObjectIdentifier(download)] = url
            completionHandler(url)
        } else {
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let url = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }  // user cancelled — not a failure
        let alert = NSAlert()
        alert.messageText = "Download Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: – Message Handler

final class LumoMessageHandler: NSObject, WKScriptMessageHandler {
    static let shared = LumoMessageHandler()

    static let pageReadyNotification = Notification.Name("LumoPageReady")

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            NotificationCenter.default.post(
                name: Self.pageReadyNotification,
                object: nil,
                userInfo: body
            )
        default:
            break
        }
    }
}
