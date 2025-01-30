import OpenFeature
import XCTest

final class ValueTests: XCTestCase {
    func testNull() {
        let value = Value.null
        XCTAssertTrue(value.isNull())
    }

    func testIntShouldConvertToInt() {
        let value: Value = .integer(3)
        XCTAssertEqual(value.asInteger(), 3)
    }

    func testDoubleShouldConvertToDouble() {
        let value: Value = .double(3.14)
        XCTAssertEqual(value.asDouble(), 3.14)
    }

    func testBoolShouldConvertToBool() {
        let value: Value = .boolean(true)
        XCTAssertEqual(value.asBoolean(), true)
    }

    func testStringShouldConvertToString() {
        let value: Value = .string("test")
        XCTAssertEqual(value.asString(), "test")
    }

    func testListShouldConvertToList() {
        let value: Value = .list([.integer(3), .integer(4)])
        XCTAssertEqual(value.asList(), [.integer(3), .integer(4)])
    }

    func testStructShouldConvertToStruct() {
        let value: Value = .structure(["field1": .integer(3), "field2": .string("test")])
        XCTAssertEqual(value.asStructure(), ["field1": .integer(3), "field2": .string("test")])
    }

    func testEmptyListAllowed() {
        let value: Value = .list([])
        XCTAssertEqual(value.asList(), [])
    }

    func testEncodeDecode() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let value: Value = .structure([
            "null": .null,
            "bool": .boolean(true),
            "int": .integer(3),
            "double": .double(4.5),
            "date": .date(date),
            "list": .list([.boolean(false), .integer(4)]),
            "structure": .structure(["int": .integer(5)]),
        ])

        let result = try JSONEncoder().encode(value)
        let decodedValue = try JSONDecoder().decode(Value.self, from: result)

        XCTAssertEqual(value, decodedValue)
    }

    func testDecodeValue() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let value: Value = .structure([
            "null": .null,
            "bool": .boolean(true),
            "int": .integer(3),
            "double": .double(4.5),
            "date": .date(date),
            "list": .list([.integer(3), .integer(5)]),
            "structure": .structure(["field1": .string("test"), "field2": .integer(12)]),
        ])
        let expected = TestValue(
            bool: true, int: 3, double: 4.5, date: date, list: [3, 5], structure: .init(field1: "test", field2: 12))

        let decodedValue: TestValue = try value.decode()

        XCTAssertEqual(decodedValue, expected)
    }

    struct TestValue: Codable, Equatable {
        var null: Bool?
        var bool: Bool
        var int: Int64
        var double: Double
        var date: Date
        var list: [Int64]
        var structure: TestSubValue
    }

    struct TestSubValue: Codable, Equatable {
        var field1: String
        var field2: Int64
    }
}
