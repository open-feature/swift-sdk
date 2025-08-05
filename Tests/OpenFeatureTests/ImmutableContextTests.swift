import XCTest
@testable import OpenFeature

final class ImmutableContextTests: XCTestCase {
    func testImmutableContextCreation() {
        let context = ImmutableContext(targetingKey: "test-key")

        XCTAssertEqual(context.getTargetingKey(), "test-key")
        XCTAssertTrue(context.keySet().isEmpty)
    }

    func testImmutableContextWithAttributes() {
        let attributes: [String: Value] = [
            "string": .string("test-value"),
            "integer": .integer(42),
            "boolean": .boolean(true),
        ]

        let context = ImmutableContext(attributes: attributes)

        XCTAssertEqual(context.getTargetingKey(), "")
        XCTAssertEqual(context.keySet().count, 3)
        XCTAssertEqual(context.getValue(key: "string")?.asString(), "test-value")
        XCTAssertEqual(context.getValue(key: "integer")?.asInteger(), 42)
        XCTAssertEqual(context.getValue(key: "boolean")?.asBoolean(), true)
    }

    func testImmutableContextDeepCopy() {
        let original = ImmutableContext(
            targetingKey: "original-key",
            structure: ImmutableStructure(attributes: [
                "key": .string("value")
            ])
        )

        guard let copy = original.deepCopy() as? ImmutableContext else {
            XCTFail("deepCopy() did not return an ImmutableContext")
            return
        }

        XCTAssertEqual(copy.getTargetingKey(), "original-key")
        XCTAssertEqual(copy.getValue(key: "key")?.asString(), "value")
        XCTAssertEqual(original.getTargetingKey(), "original-key")
        XCTAssertEqual(original.getValue(key: "key")?.asString(), "value")
    }

    func testImmutableContextFromMutableContext() {
        let mutableContext = MutableContext(targetingKey: "mutable-key")
        mutableContext.add(key: "string", value: .string("mutable-value"))
        mutableContext.add(key: "number", value: .integer(123))

        let immutableContext = ImmutableContext(from: mutableContext)

        XCTAssertEqual(immutableContext.getTargetingKey(), "mutable-key")
        XCTAssertEqual(immutableContext.keySet().count, 2)
        XCTAssertEqual(immutableContext.getValue(key: "string")?.asString(), "mutable-value")
        XCTAssertEqual(immutableContext.getValue(key: "number")?.asInteger(), 123)
    }

    func testImmutableContextAsMap() {
        let attributes: [String: Value] = [
            "string": .string("test"),
            "integer": .integer(42),
            "boolean": .boolean(true),
            "list": .list([.string("item1"), .integer(100)]),
            "structure": .structure([
                "nested": .string("nested-value")
            ]),
        ]

        let context = ImmutableContext(attributes: attributes)
        let map = context.asMap()

        XCTAssertEqual(map.count, 5)
        XCTAssertEqual(map["string"]?.asString(), "test")
        XCTAssertEqual(map["integer"]?.asInteger(), 42)
        XCTAssertEqual(map["boolean"]?.asBoolean(), true)
        XCTAssertEqual(map["list"]?.asList()?.count, 2)
        XCTAssertEqual(map["structure"]?.asStructure()?["nested"]?.asString(), "nested-value")
    }

    func testImmutableContextAsObjectMap() {
        let attributes: [String: Value] = [
            "string": .string("test"),
            "integer": .integer(42),
            "boolean": .boolean(true),
            "null": .null,
        ]

        let context = ImmutableContext(attributes: attributes)
        let objectMap = context.asObjectMap()

        XCTAssertEqual(objectMap.count, 4)
        XCTAssertEqual(objectMap["string"] as? String, "test")
        XCTAssertEqual(objectMap["integer"] as? Int64, 42)
        XCTAssertEqual(objectMap["boolean"] as? Bool, true)

        // For null values, we need to check the unwrapped value
        let nullValue = objectMap["null"]
        XCTAssertNil(nullValue as? AnyHashable) // But the unwrapped value is nil
    }

    func testImmutableContextWithTargetingKey() {
        let original = ImmutableContext(targetingKey: "original-key")
        let modified = original.withTargetingKey("new-key")

        XCTAssertEqual(original.getTargetingKey(), "original-key")
        XCTAssertEqual(modified.getTargetingKey(), "new-key")
        XCTAssertTrue(original.keySet().isEmpty)
        XCTAssertTrue(modified.keySet().isEmpty)
    }

    func testImmutableContextSetAttribute() {
        let original = ImmutableContext(targetingKey: "user-123")
        let modified = original.setAttribute(key: "country", value: .string("US"))

        XCTAssertEqual(original.getTargetingKey(), "user-123")
        XCTAssertEqual(modified.getTargetingKey(), "user-123")
        XCTAssertTrue(original.keySet().isEmpty)
        XCTAssertEqual(modified.keySet().count, 1)
        XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
        XCTAssertNil(original.getValue(key: "country"))
    }

    func testImmutableContextSetMultipleAttributes() {
        let original = ImmutableContext(targetingKey: "user-123")
        let attributes: [String: Value] = [
            "country": .string("US"),
            "age": .integer(25),
            "premium": .boolean(true),
        ]
        let modified = original.setAttributes(attributes)

        XCTAssertEqual(original.getTargetingKey(), "user-123")
        XCTAssertEqual(modified.getTargetingKey(), "user-123")
        XCTAssertTrue(original.keySet().isEmpty)
        XCTAssertEqual(modified.keySet().count, 3)
        XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
        XCTAssertEqual(modified.getValue(key: "age")?.asInteger(), 25)
        XCTAssertEqual(modified.getValue(key: "premium")?.asBoolean(), true)
    }

    func testImmutableContextRemoveAttribute() {
        let original = ImmutableContext(
            targetingKey: "user-123",
            structure: ImmutableStructure(attributes: [
                "country": .string("US"),
                "age": .integer(25),
                "premium": .boolean(true),
            ])
        )
        let modified = original.removeAttribute(key: "age")

        XCTAssertEqual(original.getTargetingKey(), "user-123")
        XCTAssertEqual(modified.getTargetingKey(), "user-123")
        XCTAssertEqual(original.keySet().count, 3)
        XCTAssertEqual(modified.keySet().count, 2)
        XCTAssertEqual(original.getValue(key: "age")?.asInteger(), 25)
        XCTAssertNil(modified.getValue(key: "age"))
        XCTAssertEqual(modified.getValue(key: "country")?.asString(), "US")
        XCTAssertEqual(modified.getValue(key: "premium")?.asBoolean(), true)
    }

    func testImmutableContextChaining() {
        let context = ImmutableContext(targetingKey: "user-123")
            .setAttribute(key: "country", value: .string("US"))
            .setAttribute(key: "age", value: .integer(25))
            .setAttribute(key: "premium", value: .boolean(true))

        XCTAssertEqual(context.getTargetingKey(), "user-123")
        XCTAssertEqual(context.keySet().count, 3)
        XCTAssertEqual(context.getValue(key: "country")?.asString(), "US")
        XCTAssertEqual(context.getValue(key: "age")?.asInteger(), 25)
        XCTAssertEqual(context.getValue(key: "premium")?.asBoolean(), true)
    }

    func testImmutableContextThreadSafetyWithModifications() {
        let original = ImmutableContext(targetingKey: "user-123")
            .setAttribute(key: "country", value: .string("US"))

        let expectation = XCTestExpectation(description: "Thread safety with modifications test")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let modified = original
                .setAttribute(key: "thread", value: .integer(Int64(index)))
                .setAttribute(key: "timestamp", value: .double(Double(index)))

            XCTAssertEqual(modified.getTargetingKey(), "user-123")
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
