import Foundation
import XCTest

@testable import OpenFeature

/// Guards the privacy manifest shipped with the SDK.
///
/// Apple requires third-party SDKs to bundle a `PrivacyInfo.xcprivacy` file describing
/// tracking, collected data and required-reason API usage. This SDK does none of those,
/// so the manifest must exist, be bundled as a resource and declare nothing.
final class PrivacyManifestTests: XCTestCase {
    /// Loads `PrivacyInfo.xcprivacy` from the package resource bundle and parses it as a plist.
    ///
    /// - Returns: The manifest's top-level dictionary.
    /// - Throws: If the file is not bundled, cannot be read, or is not a plist dictionary.
    private func loadManifest() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy must be bundled as a package resource"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any], "PrivacyInfo.xcprivacy must be a plist dictionary")
    }

    /// Verifies the manifest is bundled as a resource and contains exactly the four keys
    /// Apple defines for a privacy manifest.
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

    /// Verifies the manifest declares that the SDK does not track users and contacts
    /// no tracking domains.
    func testManifestDeclaresNoTracking() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(try XCTUnwrap(manifest["NSPrivacyTrackingDomains"] as? [Any]).count, 0)
    }

    /// Verifies the manifest declares that the SDK collects no data types.
    func testManifestDeclaresNoCollectedData() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(try XCTUnwrap(manifest["NSPrivacyCollectedDataTypes"] as? [Any]).count, 0)
    }

    /// Verifies the manifest declares that the SDK calls no required-reason APIs.
    func testManifestDeclaresNoRequiredReasonAPIs() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [Any]).count, 0)
    }
}
