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
}
