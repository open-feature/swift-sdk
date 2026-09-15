import Foundation
import XCTest

@testable import OpenFeature

/// Guards the privacy manifest shipped with the SDK.
///
/// Apple requires third-party SDKs to bundle a `PrivacyInfo.xcprivacy` file describing
/// tracking, collected data and required-reason API usage. This SDK does none of those,
/// so the manifest must exist, be bundled as a resource and declare nothing.
final class PrivacyManifestTests: XCTestCase {
    private func loadManifest() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy must be bundled as a package resource"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any], "PrivacyInfo.xcprivacy must be a plist dictionary")
    }

    func testManifestIsBundled() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(
            Set(manifest.keys),
            [
                "NSPrivacyTracking",
                "NSPrivacyTrackingDomains",
                "NSPrivacyCollectedDataTypes",
                "NSPrivacyAccessedAPITypes",
            ]
        )
    }

    func testManifestDeclaresNoTracking() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(try XCTUnwrap(manifest["NSPrivacyTrackingDomains"] as? [Any]).count, 0)
    }

    func testManifestDeclaresNoCollectedData() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(try XCTUnwrap(manifest["NSPrivacyCollectedDataTypes"] as? [Any]).count, 0)
    }

    func testManifestDeclaresNoRequiredReasonAPIs() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [Any]).count, 0)
    }
}
