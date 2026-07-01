import AppKit
import WebKit

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
    private(set) var webView: WKWebView!
    private var findBar: NSSearchField?
    private var findBarHeightConstraint: NSLayoutConstraint?
    private var progressObserver: NSKeyValueObservation?
    private var titleObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var canGoBackObserver: NSKeyValueObservation?
    private var canGoForwardObserver: NSKeyValueObservation?

    private static let lumoURL = URL(string: "https://lumo.proton.me/")!

    // MARK: – Init

    init(settings: AppSettings, urlString: String? = nil) {
        self.settings = settings
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

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        self.view = container

        // Navigate.
        let targetURL = URL(string: "https://lumo.proton.me/") ?? Self.lumoURL
        webView.load(URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy))

        // Observe properties for UI updates.
        observeWebView()
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
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif

        // Inject user content controller for native bridge + styling.
        let ucc = WKUserContentController()
        injectNativeEnhancements(into: ucc)
        config.userContentController = ucc

        // Custom user agent for best compatibility.
        if settings.customUserAgent {
            config.applicationNameForUserAgent = "Lumo/1.0"
            // We'll set a fine-tuned UA on the webView instance after creation.
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

        /* Smooth scrolling that feels native. */
        * {
            scroll-behavior: smooth;
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

        canGoBackObserver = webView.observe(\.canGoBack, options: [.new]) { _, _ in
            // Could update toolbar item enabled state here.
        }

        canGoForwardObserver = webView.observe(\.canGoForward, options: [.new]) { _, _ in
            // Could update toolbar item enabled state here.
        }
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
                self.webView.load(URLRequest(url: URL(string: "https://lumo.proton.me/")!))
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

        guard let url = navigationAction.targetFrame?.request.url ?? navigationAction.request.url else {
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
        if let title = webView.title, !title.isEmpty {
            view.window?.title = title
        } else {
            view.window?.title = "Lumo"
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Show error page for network failures.
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            showOfflinePage()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            showOfflinePage()
        }
    }

    // MARK: – Authentication Challenge

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Use default handling for TLS certs.
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: – Offline Page

    private func showOfflinePage() {
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
            <p>You appear to be offline. Check your internet connection and try again.</p>
            <button onclick="location.href='https://lumo.proton.me/'">Retry</button>
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

// MARK: – Message Handler

final class LumoMessageHandler: NSObject, WKScriptMessageHandler {
    static let shared = LumoMessageHandler()

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            // Page DOM is ready — could trigger further injections.
            break
        default:
            break
        }
    }
}