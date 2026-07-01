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

    static func decide(for url: URL, blockTrackers: Bool) -> NavigationAction {
        // Block known tracking domains.
        if blockTrackers, let host = url.host {
            let trackerDomains = ["google-analytics.com", "doubleclick.net", "facebook.net",
                                  "facebook.com", "hotjar.com", "segment.io", "amplitude.com",
                                  "mixpanel.com", "fullstory.com", "snowplowanalytics.com"]
            if trackerDomains.contains(where: { host.contains($0) }) {
                return .cancel
            }
        }

        // Allow same-origin navigation to proton.me domains.
        if let host = url.host, host.hasSuffix("proton.me") {
            return .allow
        }

        // External HTTP(S) links open in default browser.
        if url.scheme == "http" || url.scheme == "https" {
            return .openExternal
        }

        return .allow
    }
}