import Foundation
import OpenFeature
import XCTest

final class EvalContextTests: XCTestCase {
    func testContextStoresTargetingKey() {
        let ctx = MutableContext()
        ctx.setTargetingKey(targetingKey: "test")
        XCTAssertEqual(ctx.getTargetingKey(), "test")
    }

    func testContextStoresPrimitiveValues() {
        let ctx = MutableContext()

        ctx.add(key: "string", value: .string("value"))
        XCTAssertEqual(ctx.getValue(key: "string")?.asString(), "value")

        ctx.add(key: "bool", value: .boolean(true))
        XCTAssertEqual(ctx.getValue(key: "bool")?.asBoolean(), true)

        ctx.add(key: "int", value: .integer(3))
        XCTAssertEqual(ctx.getValue(key: "int")?.asInteger(), 3)

        ctx.add(key: "double", value: .double(3.14))
        XCTAssertEqual(ctx.getValue(key: "double")?.asDouble(), 3.14)

        let date = Date()
        ctx.add(key: "date", value: .date(date))
        XCTAssertEqual(ctx.getValue(key: "date")?.asDate(), date)
    }

    func testContextStoresLists() {
        let ctx = MutableContext()

        ctx.add(key: "list", value: .list([.integer(3), .integer(4)]))
        XCTAssertEqual(ctx.getValue(key: "list")?.asList()?[0].asInteger(), 3)
        XCTAssertEqual(ctx.getValue(key: "list")?.asList()?[1].asInteger(), 4)
    }

    func testContextStoresStructures() {
        let ctx = MutableContext()

        ctx.add(key: "struct", value: .structure(["string": .string("test"), "int": .integer(3)]))
        XCTAssertEqual(ctx.getValue(key: "struct")?.asStructure()?["string"]?.asString(), "test")
        XCTAssertEqual(ctx.getValue(key: "struct")?.asStructure()?["int"]?.asInteger(), 3)
    }

    func testContextCanConvertToMap() {
        let ctx = MutableContext()

        ctx.add(key: "str", value: .string("test"))
        ctx.add(key: "str2", value: .string("test2"))

        ctx.add(key: "bool", value: .boolean(true))
        ctx.add(key: "bool2", value: .boolean(false))

        ctx.add(key: "int", value: .integer(4))
        ctx.add(key: "int2", value: .integer(2))

        let date = Date()
        ctx.add(key: "dt", value: .date(date))

        ctx.add(key: "obj", value: .structure(["val1": .integer(1), "val2": .string("2")]))

        let map = ctx.asMap()
        XCTAssertEqual(map["str"]?.asString(), "test")
        XCTAssertEqual(map["str2"]?.asString(), "test2")

        XCTAssertEqual(map["bool"]?.asBoolean(), true)
        XCTAssertEqual(map["bool2"]?.asBoolean(), false)

        XCTAssertEqual(map["int"]?.asInteger(), 4)
        XCTAssertEqual(map["int2"]?.asInteger(), 2)

        XCTAssertEqual(map["dt"]?.asDate(), date)

        let structure = map["obj"]?.asStructure()
        XCTAssertEqual(structure?["val1"]?.asInteger(), 1)
        XCTAssertEqual(structure?["val2"]?.asString(), "2")
    }

    func testContextHasUniqueKeyAcrossTypes() {
        let ctx = MutableContext()

        ctx.add(key: "key", value: .string("val"))
        ctx.add(key: "key", value: .string("val2"))
        XCTAssertEqual(ctx.getValue(key: "key")?.asString(), "val2")

        ctx.add(key: "key", value: .integer(3))
        XCTAssertNil(ctx.getValue(key: "key")?.asString())
        XCTAssertEqual(ctx.getValue(key: "key")?.asInteger(), 3)
    }

    func testContextCanChainAttributeAddition() {
        let ctx = MutableContext()

        let result =
            ctx
            .add(key: "key1", value: .string("val"))
            .add(key: "key2", value: .string("val2"))

        XCTAssertEqual(result.getValue(key: "key1")?.asString(), "val")
        XCTAssertEqual(result.getValue(key: "key2")?.asString(), "val2")
    }

    func testContextCanAddNull() {
        let ctx = MutableContext()

        ctx.add(key: "null", value: .null)

        XCTAssertEqual(ctx.getValue(key: "null")?.isNull(), true)
        XCTAssertNil(ctx.getValue(key: "null")?.asString())
    }

    func testContextConvertsToObjectMap() {
        let key1 = "key1"
        let date = Date()
        let ctx = MutableContext(targetingKey: key1)
        ctx.add(key: "string", value: .string("value"))
        ctx.add(key: "bool", value: .boolean(false))
        ctx.add(key: "integer", value: .integer(1))
        ctx.add(key: "double", value: .double(1.2))
        ctx.add(key: "date", value: .date(date))
        ctx.add(key: "list", value: .list([.string("item1"), .string("item2")]))
        ctx.add(key: "structure", value: .structure(["field1": .integer(3), "field2": .double(3.14)]))

        let expected: [String: AnyHashable] = [
            "string": "value",
            "bool": false,
            "integer": 1,
            "double": 1.2,
            "date": date,
            "list": ["item1", "item2"],
            "structure": ["field1": 3, "field2": 3.14],
        ]

        XCTAssertEqual(ctx.asObjectMap(), expected)
    }

    func testContextDeepCopyCreatesIndependentCopy() {
        // Create original context with various data types
        let originalContext = MutableContext(targetingKey: "original-key")
        originalContext.add(key: "string", value: .string("original-value"))
        originalContext.add(key: "integer", value: .integer(42))
        originalContext.add(key: "boolean", value: .boolean(true))
        originalContext.add(key: "list", value: .list([.string("item1"), .integer(100)]))
        originalContext.add(
            key: "structure",
            value: .structure([
                "nested-string": .string("nested-value"),
                "nested-int": .integer(200),
            ]))

        guard let copiedContext = originalContext.deepCopy() as? MutableContext else {
            XCTFail("Failed to cast to MutableContext")
            return
        }

        XCTAssertEqual(copiedContext.getTargetingKey(), "original-key")
        XCTAssertEqual(copiedContext.getValue(key: "string")?.asString(), "original-value")
        XCTAssertEqual(copiedContext.getValue(key: "integer")?.asInteger(), 42)
        XCTAssertEqual(copiedContext.getValue(key: "boolean")?.asBoolean(), true)
        XCTAssertEqual(copiedContext.getValue(key: "list")?.asList()?[0].asString(), "item1")
        XCTAssertEqual(copiedContext.getValue(key: "list")?.asList()?[1].asInteger(), 100)
        XCTAssertEqual(
            copiedContext.getValue(key: "structure")?.asStructure()?["nested-string"]?.asString(),
            "nested-value"
        )
        XCTAssertEqual(copiedContext.getValue(key: "structure")?.asStructure()?["nested-int"]?.asInteger(), 200)

        originalContext.setTargetingKey(targetingKey: "modified-key")
        originalContext.add(key: "string", value: .string("modified-value"))
        originalContext.add(key: "new-key", value: .string("new-value"))

        XCTAssertEqual(copiedContext.getTargetingKey(), "original-key")
        XCTAssertEqual(copiedContext.getValue(key: "string")?.asString(), "original-value")
        XCTAssertNil(copiedContext.getValue(key: "new-key"))
        XCTAssertEqual(originalContext.getTargetingKey(), "modified-key")
        XCTAssertEqual(originalContext.getValue(key: "string")?.asString(), "modified-value")
        XCTAssertEqual(originalContext.getValue(key: "new-key")?.asString(), "new-value")
    }

    func testContextDeepCopyWithEmptyContext() {
        let emptyContext = MutableContext()
        guard let copiedContext = emptyContext.deepCopy() as? MutableContext else {
            XCTFail("Failed to cast to MutableContext")
            return
        }

        XCTAssertEqual(emptyContext.getTargetingKey(), "")
        XCTAssertEqual(copiedContext.getTargetingKey(), "")
        XCTAssertTrue(emptyContext.keySet().isEmpty)
        XCTAssertTrue(copiedContext.keySet().isEmpty)

        emptyContext.setTargetingKey(targetingKey: "test")
        emptyContext.add(key: "key", value: .string("value"))

        XCTAssertEqual(copiedContext.getTargetingKey(), "")
        XCTAssertTrue(copiedContext.keySet().isEmpty)
    }

    func testContextDeepCopyPreservesAllValueTypes() {
        let date = Date()
        let originalContext = MutableContext(targetingKey: "test-key")
        originalContext.add(key: "null", value: .null)
        originalContext.add(key: "string", value: .string("test-string"))
        originalContext.add(key: "boolean", value: .boolean(false))
        originalContext.add(key: "integer", value: .integer(12345))
        originalContext.add(key: "double", value: .double(3.14159))
        originalContext.add(key: "date", value: .date(date))
        originalContext.add(key: "list", value: .list([.string("list-item"), .integer(999)]))
        originalContext.add(
            key: "structure",
            value: .structure([
                "struct-key": .string("struct-value"),
                "struct-number": .integer(777),
            ]))

        guard let copiedContext = originalContext.deepCopy() as? MutableContext else {
            XCTFail("Failed to cast to MutableContext")
            return
        }

        XCTAssertTrue(copiedContext.getValue(key: "null")?.isNull() ?? false)
        XCTAssertEqual(copiedContext.getValue(key: "string")?.asString(), "test-string")
        XCTAssertEqual(copiedContext.getValue(key: "boolean")?.asBoolean(), false)
        XCTAssertEqual(copiedContext.getValue(key: "integer")?.asInteger(), 12345)
        XCTAssertEqual(copiedContext.getValue(key: "double")?.asDouble(), 3.14159)
        XCTAssertEqual(copiedContext.getValue(key: "date")?.asDate(), date)
        XCTAssertEqual(copiedContext.getValue(key: "list")?.asList()?[0].asString(), "list-item")
        XCTAssertEqual(copiedContext.getValue(key: "list")?.asList()?[1].asInteger(), 999)
        XCTAssertEqual(
            copiedContext.getValue(key: "structure")?.asStructure()?["struct-key"]?.asString(),
            "struct-value"
        )
        XCTAssertEqual(copiedContext.getValue(key: "structure")?.asStructure()?["struct-number"]?.asInteger(), 777)
    }

    func testContextDeepCopyIsThreadSafe() {
        let context = MutableContext(targetingKey: "initial-key")
        context.add(key: "initial", value: .string("initial-value"))

        let expectation = XCTestExpectation(description: "Concurrent deep copy operations")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // Perform multiple concurrent operations
        for i in 0..<100 {
            group.enter()
            concurrentQueue.async {
                // Modify the context
                context.setTargetingKey(targetingKey: "modified-\(i)")
                context.add(key: "key-\(i)", value: .integer(Int64(i)))

                // Perform deep copy
                let copiedContext = context.deepCopy()

                // Verify the copy is independent
                XCTAssertNotEqual(copiedContext.getTargetingKey(), "initial-key")
                XCTAssertNotNil(copiedContext.getValue(key: "initial"))

                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
