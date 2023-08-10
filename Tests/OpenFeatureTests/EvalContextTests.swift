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
}
