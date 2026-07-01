import XCTest
@testable import Lumo

final class NavigationPolicyTests: XCTestCase {

    // MARK: – Proton domain handling

    func testProtonMainDomainAllowed() {
        let url = URL(string: "https://lumo.proton.me/")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }

    func testProtonSubdomainAllowed() {
        let url = URL(string: "https://account.proton.me/login")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }

    func testProtonMeRootAllowed() {
        let url = URL(string: "https://proton.me/")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }

    // MARK: – External links

    func testExternalHTTPLinkOpenedExternally() {
        let url = URL(string: "https://example.com/")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .openExternal)
    }

    func testExternalHTTPLinkOpenedExternally2() {
        let url = URL(string: "http://example.org/page")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .openExternal)
    }

    // MARK: – Tracker blocking (fixed domain matching)

    func testTrackerDomainBlocked() {
        let url = URL(string: "https://google-analytics.com/collect")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .cancel)
    }

    func testTrackerSubdomainBlocked() {
        let url = URL(string: "https://www.doubleclick.net/ad")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .cancel)
    }

    func testTrackerSubdomainDeepBlocked() {
        let url = URL(string: "https://ads.google-analytics.com/collect")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .cancel)
    }

    func testNonTrackerDomainWithTrackerSubstringNotBlocked() {
        // This domain contains "facebook.com" as a substring but is not
        // facebook.com or a subdomain — should NOT be blocked (was a false
        // positive before the fix).
        let url = URL(string: "https://not-facebook.com/")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .openExternal)
    }

    func testTrackerBlockingDisabledAllowsTracker() {
        let url = URL(string: "https://google-analytics.com/collect")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: false), .openExternal)
    }

    // MARK: – Non-HTTP schemes

    func testNonHTTPSchemeAllowed() {
        let url = URL(string: "mailto:someone@example.com")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }

    // MARK: – Edge cases

    func testURLWithNoHostAllowed() {
        let url = URL(string: "about:blank")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }

    // MARK: – Domain suffix matching (phishing prevention)

    func testPhishingDomainNotAllowed() {
        let url = URL(string: "https://evilproton.me/")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .openExternal)
    }

    func testFakeProtonDomainNotAllowed() {
        let url = URL(string: "https://fakeproton.me/login")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .openExternal)
    }

    func testProtonSubdomainStillAllowed() {
        let url = URL(string: "https://lumo.proton.me/chat")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }

    func testExactProtonMeAllowed() {
        let url = URL(string: "https://proton.me/")!
        XCTAssertEqual(NavigationPolicy.decide(for: url, blockTrackers: true), .allow)
    }
}