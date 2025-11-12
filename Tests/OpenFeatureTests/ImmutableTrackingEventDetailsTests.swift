import XCTest

@testable import OpenFeature

final class ImmutableTrackingEventDetailsTests: XCTestCase {
    func testImmutableTrackingEventDetailsCreation() {
        let context = ImmutableTrackingEventDetails(value: 5)

        XCTAssertEqual(context.getValue(), 5)
        XCTAssertTrue(context.keySet().isEmpty)
    }

    func testImmutableTrackingEventDetailsWithAttributes() {
        let attributes: [String: Value] = [
            "string": .string("test-value"),
            "integer": .integer(42),
            "boolean": .boolean(true),
        ]

        let context = ImmutableTrackingEventDetails(attributes: attributes)

        XCTAssertNil(context.getValue())
        XCTAssertEqual(context.keySet().count, 3)
        XCTAssertEqual(context.getValue(key: "string")?.asString(), "test-value")
        XCTAssertEqual(context.getValue(key: "integer")?.asInteger(), 42)
        XCTAssertEqual(context.getValue(key: "boolean")?.asBoolean(), true)
    }

    func testImmutableTrackingEventDetailsAsMap() {
        let attributes: [String: Value] = [
            "string": .string("test"),
            "integer": .integer(42),
            "boolean": .boolean(true),
            "list": .list([.string("item1"), .integer(100)]),
            "structure": .structure([
                "nested": .string("nested-value")
            ]),
        ]

        let context = ImmutableTrackingEventDetails(attributes: attributes)
        let map = context.asMap()

        XCTAssertEqual(map.count, 5)
        XCTAssertEqual(map["string"]?.asString(), "test")
        XCTAssertEqual(map["integer"]?.asInteger(), 42)
        XCTAssertEqual(map["boolean"]?.asBoolean(), true)
        XCTAssertEqual(map["list"]?.asList()?.count, 2)
        XCTAssertEqual(map["structure"]?.asStructure()?["nested"]?.asString(), "nested-value")
    }

    func testImmutableTrackingEventDetailsAsObjectMap() {
        let attributes: [String: Value] = [
            "string": .string("test"),
            "integer": .integer(42),
            "boolean": .boolean(true),
            "null": .null,
        ]

        let context = ImmutableTrackingEventDetails(attributes: attributes)
        let objectMap = context.asObjectMap()

        XCTAssertEqual(objectMap.count, 4)
        XCTAssertEqual(objectMap["string"] as? String, "test")
        XCTAssertEqual(objectMap["integer"] as? Int64, 42)
        XCTAssertEqual(objectMap["boolean"] as? Bool, true)

        // For null values, we need to check the unwrapped value
        let nullValue = objectMap["null"]
        XCTAssertNil(nullValue as? AnyHashable)  // But the unwrapped value is nil
    }

    func testImmutableTrackingEventDetailsWithValue() {
        let original = ImmutableTrackingEventDetails(value: 0)
        let modified = original.withValue(2)

        XCTAssertEqual(original.getValue(), 0)
        XCTAssertEqual(modified.getValue(), 2)
        XCTAssertTrue(original.keySet().isEmpty)
        XCTAssertTrue(modified.keySet().isEmpty)
    }

    func testImmutableTrackingEventDetailsSetAttribute() {
        let original = ImmutableTrackingEventDetails(value: 3)
        let modified = original.withAttribute(key: "country", value: .string("US"))

        XCTAssertEqual(original.getValue(), 3)
        XCTAssertEqual(modified.getValue(), 3)
        XCTAssertTrue(original.keySet().isEmpty)
        XCTAssertEqual(modified.keySet().count, 1)
        XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
        XCTAssertNil(original.getValue(key: "country"))
    }

    func testImmutableTrackingEventDetailsSetMultipleAttributes() {
        let original = ImmutableTrackingEventDetails(value: 3)
        let attributes: [String: Value] = [
            "country": .string("US"),
            "age": .integer(25),
            "premium": .boolean(true),
        ]
        let modified = original.withAttributes(attributes)

        XCTAssertEqual(original.getValue(), 3)
        XCTAssertEqual(modified.getValue(), 3)
        XCTAssertTrue(original.keySet().isEmpty)
        XCTAssertEqual(modified.keySet().count, 3)
        XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
        XCTAssertEqual(modified.getValue(key: "age")?.asInteger(), 25)
        XCTAssertEqual(modified.getValue(key: "premium")?.asBoolean(), true)
    }

    func testImmutableTrackingEventDetailsRemoveAttribute() {
        let original = ImmutableTrackingEventDetails(
            value: 1,
            structure: ImmutableStructure(attributes: [
                "country": .string("US"),
                "age": .integer(25),
                "premium": .boolean(true),
            ])
        )
        let modified = original.withoutAttribute(key: "age")

        XCTAssertEqual(original.getValue(), 1)
        XCTAssertEqual(modified.getValue(), 1)
        XCTAssertEqual(original.keySet().count, 3)
        XCTAssertEqual(modified.keySet().count, 2)
        XCTAssertEqual(original.getValue(key: "age")?.asInteger(), 25)
        XCTAssertNil(modified.getValue(key: "age"))
        XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
        XCTAssertEqual(modified.getValue(key: "premium")?.asBoolean(), true)
    }

    func testImmutableTrackingEventDetailsChaining() {
        let context = ImmutableTrackingEventDetails(value: 1)
            .withAttribute(key: "country", value: .string("US"))
            .withAttribute(key: "age", value: .integer(25))
            .withAttribute(key: "premium", value: .boolean(true))

        XCTAssertEqual(context.getValue(), 1)
        XCTAssertEqual(context.keySet().count, 3)
        XCTAssertEqual(context.getValue(key: "country")?.asString(), "US")
        XCTAssertEqual(context.getValue(key: "age")?.asInteger(), 25)
        XCTAssertEqual(context.getValue(key: "premium")?.asBoolean(), true)
    }

    func testImmutableTrackingEventDetailsThreadSafetyWithModifications() {
        let original = ImmutableTrackingEventDetails(value: 1)
            .withAttribute(key: "country", value: .string("US"))

        let expectation = XCTestExpectation(description: "Thread safety with modifications test")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let modified =
                original
                .withAttribute(key: "thread", value: .integer(Int64(index)))
                .withAttribute(key: "timestamp", value: .double(Double(index)))

            XCTAssertEqual(modified.getValue(), 1)
            XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
            XCTAssertEqual(modified.getValue(key: "thread")?.asInteger(), Int64(index))
            XCTAssertEqual(modified.getValue(key: "timestamp")?.asDouble(), Double(index))

            XCTAssertEqual(original.keySet().count, 1)
            XCTAssertEqual(original.getValue(key: "country")?.asString(), "US")
            XCTAssertNil(original.getValue(key: "thread"))
            XCTAssertNil(original.getValue(key: "timestamp"))

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
