import XCTest
@testable import Lumo

final class UpdateCheckerTests: XCTestCase {

    // MARK: – isNewer

    func testNewerPatchVersionDetected() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "1.0.3", than: "1.0.2"))
    }

    func testEqualVersionsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "1.0.2", than: "1.0.2"))
    }

    func testNumericNotLexicographicComparison() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "1.0.10", than: "1.0.2"))
    }

    func testShorterVersionCompared() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "1.1", than: "1.0.9"))
    }

    func testPaddedVersionsEqual() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "1.0", than: "1.0.0"))
    }

    func testOlderVersionNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.9.9", than: "1.0.0"))
    }

    // MARK: – parseLatestRelease

    func testParsesTagAndURLStrippingLeadingV() {
        let json = """
        {"tag_name": "v1.2.0", "html_url": "https://github.com/svcho/Lumo-for-Mac/releases/tag/v1.2.0"}
        """
        let data = Data(json.utf8)
        let release = UpdateChecker.parseLatestRelease(from: data)
        XCTAssertEqual(release?.version, "1.2.0")
        XCTAssertEqual(release?.url, URL(string: "https://github.com/svcho/Lumo-for-Mac/releases/tag/v1.2.0"))
    }

    func testMalformedJSONReturnsNil() {
        let data = Data("not json".utf8)
        XCTAssertNil(UpdateChecker.parseLatestRelease(from: data))
    }

    func testMissingTagNameReturnsNil() {
        let json = """
        {"html_url": "https://github.com/svcho/Lumo-for-Mac/releases/tag/v1.2.0"}
        """
        let data = Data(json.utf8)
        XCTAssertNil(UpdateChecker.parseLatestRelease(from: data))
    }
}
