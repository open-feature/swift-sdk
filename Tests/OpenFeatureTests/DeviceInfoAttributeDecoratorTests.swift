import XCTest

@testable import OpenFeature

final class DeviceInfoAttributeDecoratorTests: XCTestCase {
    func testEmptyConstructMakesNoOp() {
        let result = DeviceInfoAttributeDecorator().decorated(attributes: [:])
        XCTAssertEqual(result.count, 0)
    }

    func testAddDeviceInfo() {
        let result = DeviceInfoAttributeDecorator(withDeviceInfo: true).decorated(attributes: [:])
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result["device"])
        XCTAssertNotNil(result["device"]?.asStructure()?["model"])
        XCTAssertNotNil(result["device"]?.asStructure()?["type"])
        XCTAssertNotNil(result["device"]?.asStructure()?["manufacturer"])
    }

    func testAddLocale() {
        let result = DeviceInfoAttributeDecorator(withLocale: true).decorated(attributes: [:])
        XCTAssertEqual(result.count, 2)
        XCTAssertNotNil(result["locale"])
        XCTAssertNotNil(result["preferred_languages"])
    }

    func testAddAppInfo() {
        let result = DeviceInfoAttributeDecorator(withAppInfo: true).decorated(attributes: [:])
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result["app"])
        XCTAssertNotNil(result["app"]?.asStructure()?["version"])
        XCTAssertNotNil(result["app"]?.asStructure()?["build"])
        XCTAssertNotNil(result["app"]?.asStructure()?["namespace"])
    }

    func testAddOsInfo() {
        let result = DeviceInfoAttributeDecorator(withOsInfo: true).decorated(attributes: [:])
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result["os"])
        XCTAssertNotNil(result["os"]?.asStructure()?["name"])
        XCTAssertNotNil(result["os"]?.asStructure()?["version"])
    }

    func testAppendsData() {
        let result = DeviceInfoAttributeDecorator(
            withDeviceInfo: true
        ).decorated(attributes: ["my_key": .double(42.0)])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["my_key"]?.asDouble(), 42.0)
        XCTAssertNotNil(result["device"])
    }

    func testCombinedAttributes() {
        let result = DeviceInfoAttributeDecorator(
            withDeviceInfo: true,
            withAppInfo: true,
            withOsInfo: true,
            withLocale: true
        ).decorated(attributes: [:])

        XCTAssertEqual(result.count, 5)
        XCTAssertNotNil(result["device"])
        XCTAssertNotNil(result["app"])
        XCTAssertNotNil(result["os"])
        XCTAssertNotNil(result["locale"])
    }
}
