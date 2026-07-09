import Foundation

/// The action to take for a given navigation request.
enum NavigationAction: Equatable {
    case allow          // Load in-app
    case openExternal   // Open in default browser, cancel in-app
    case cancel         // Block entirely
}

/// Pure URL classification logic extracted from WebViewController's navigation delegate.
/// This is testable without instantiating WKWebView.
enum NavigationPolicy {

    private static let trackerDomains: Set<String> = [
        "google-analytics.com", "doubleclick.net", "facebook.net",
        "facebook.com", "hotjar.com", "segment.io", "amplitude.com",
        "mixpanel.com", "fullstory.com", "snowplowanalytics.com",
    ]

    static func decide(for url: URL, blockTrackers: Bool) -> NavigationAction {
        // Block known tracking domains.
        if blockTrackers, let host = url.host {
            if Self.trackerDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
                return .cancel
            }
        }

        // Allow same-origin navigation to proton.me domains.
        if let host = url.host, host == "proton.me" || host.hasSuffix(".proton.me") {
            return .allow
        }

        // External HTTP(S) links open in default browser.
        if url.scheme == "http" || url.scheme == "https" {
            return .openExternal
        }

        // Schemes WebKit must handle internally.
        if url.scheme == "about" || url.scheme == "blob" {
            return .allow
        }

        // User-intent schemes handled by other apps (Mail, FaceTime, …).
        if let scheme = url.scheme,
           ["mailto", "tel", "facetime", "sms"].contains(scheme) {
            return .openExternal
        }

        // Default-deny anything else.
        return .cancel
    }
}