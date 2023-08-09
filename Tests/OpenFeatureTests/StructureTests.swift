import Foundation
import OpenFeature
import XCTest

final class StructureTests: XCTestCase {
    func testNoArgIsEmpty() {
        let structure = MutableStructure()
        XCTAssertTrue(structure.asMap().keys.isEmpty)
    }

    func testArgShouldContainNewMap() {
        let map = ["key": Value.string("test")]

        let structure = MutableStructure(attributes: map)

        XCTAssertEqual(structure.getValue(key: "key")?.asString(), "test")
        XCTAssertEqual(structure.asMap(), map)
    }

    func testAddAndGetReturnValues() {
        let date = Date()
        let structure = MutableStructure()
        structure.add(key: "bool", value: .boolean(true))
        structure.add(key: "string", value: .string("val"))
        structure.add(key: "int", value: .integer(13))
        structure.add(key: "double", value: .double(0.5))
        structure.add(key: "date", value: .date(date))
        structure.add(key: "list", value: .list([]))
        structure.add(key: "structure", value: .structure([:]))

        XCTAssertEqual(structure.getValue(key: "bool")?.asBoolean(), true)
        XCTAssertEqual(structure.getValue(key: "string")?.asString(), "val")
        XCTAssertEqual(structure.getValue(key: "int")?.asInteger(), 13)
        XCTAssertEqual(structure.getValue(key: "double")?.asDouble(), 0.5)
        XCTAssertEqual(structure.getValue(key: "date")?.asDate(), date)
        XCTAssertEqual(structure.getValue(key: "list")?.asList(), [])
        XCTAssertEqual(structure.getValue(key: "structure")?.asStructure(), [:])
    }
}
