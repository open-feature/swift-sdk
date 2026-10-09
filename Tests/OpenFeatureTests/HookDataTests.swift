import Foundation
import XCTest

@testable import OpenFeature

final class HookDataTests: XCTestCase {
    // MARK: - Empty state

    func testStartsEmpty() {
        let data = HookData()

        XCTAssertTrue(data.isEmpty)
        XCTAssertTrue(data.keys.isEmpty)
        XCTAssertNil(data["anything"])
    }

    // MARK: - Reading and writing

    func testStoresAndReadsBackValue() {
        let data = HookData()

        data["answer"] = 42

        XCTAssertEqual(data["answer"] as? Int, 42)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.keys, ["answer"])
    }

    func testOverwritesExistingValue() {
        let data = HookData()

        data["key"] = "first"
        data["key"] = "second"

        XCTAssertEqual(data["key"] as? String, "second")
        XCTAssertEqual(data.keys, ["key"])
    }

    func testAssigningNilRemovesKey() {
        let data = HookData()
        data["key"] = "value"

        data["key"] = nil

        XCTAssertNil(data["key"])
        XCTAssertTrue(data.isEmpty)
        XCTAssertTrue(data.keys.isEmpty)
    }

    func testAssigningNilToMissingKeyIsNoOp() {
        let data = HookData()

        data["missing"] = nil

        XCTAssertTrue(data.isEmpty)
    }

    func testKeysReflectEveryStoredKey() {
        let data = HookData()

        data["a"] = 1
        data["b"] = 2
        data["c"] = 3

        XCTAssertEqual(data.keys, ["a", "b", "c"])
    }

    func testKeysAreIndependent() {
        let data = HookData()

        data["a"] = 1
        data["b"] = 2

        XCTAssertEqual(data["a"] as? Int, 1)
        XCTAssertEqual(data["b"] as? Int, 2)
    }

    // MARK: - Value types (spec 4.6.1: values of any type)

    func testStoresValueOfAnyType() {
        struct Point: Equatable {
            let x: Int
            let y: Int
        }
        let data = HookData()
        let date = Date()

        data["int"] = 1
        data["double"] = 1.5
        data["string"] = "text"
        data["bool"] = true
        data["date"] = date
        data["struct"] = Point(x: 1, y: 2)
        data["array"] = [1, 2, 3]
        data["dictionary"] = ["nested": "value"]
        data["value"] = Value.structure(["flag": .boolean(true)])

        XCTAssertEqual(data["int"] as? Int, 1)
        XCTAssertEqual(data["double"] as? Double, 1.5)
        XCTAssertEqual(data["string"] as? String, "text")
        XCTAssertEqual(data["bool"] as? Bool, true)
        XCTAssertEqual(data["date"] as? Date, date)
        XCTAssertEqual(data["struct"] as? Point, Point(x: 1, y: 2))
        XCTAssertEqual(data["array"] as? [Int], [1, 2, 3])
        XCTAssertEqual(data["dictionary"] as? [String: String], ["nested": "value"])
        XCTAssertEqual(data["value"] as? Value, .structure(["flag": .boolean(true)]))
    }

    func testStoresReferenceTypeByIdentity() {
        final class Span {
            var ended = false
        }
        let data = HookData()
        let span = Span()

        data["span"] = span
        (data["span"] as? Span)?.ended = true

        XCTAssertTrue((data["span"] as? Span) === span)
        XCTAssertTrue(span.ended)
    }

    func testStoresClosure() {
        let data = HookData()
        var called = false

        data["callback"] = { called = true } as () -> Void
        (data["callback"] as? () -> Void)?()

        XCTAssertTrue(called)
    }

    func testReadingWithWrongTypeReturnsNil() {
        let data = HookData()
        data["number"] = 1

        XCTAssertNil(data["number"] as? String)
        XCTAssertNotNil(data["number"])
    }

    // MARK: - Isolation

    func testInstancesDoNotShareStorage() {
        let first = HookData()
        let second = HookData()

        first["key"] = "first"

        XCTAssertNil(second["key"])
        XCTAssertTrue(second.isEmpty)
    }

    func testIsReferenceType() {
        let data = HookData()
        let alias = data

        alias["key"] = "value"

        XCTAssertEqual(data["key"] as? String, "value")
    }

    // MARK: - Thread safety

    func testConcurrentReadsAndWritesAreSerialised() {
        let data = HookData()
        let iterations = 1_000

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            data["key-\(index)"] = index
            _ = data["key-\(index / 2)"]
            _ = data.keys
            _ = data.isEmpty
        }

        XCTAssertEqual(data.keys.count, iterations)
        XCTAssertEqual(data["key-0"] as? Int, 0)
        XCTAssertEqual(data["key-\(iterations - 1)"] as? Int, iterations - 1)
    }

    func testConcurrentWritesToSameKeyKeepStoreConsistent() {
        let data = HookData()
        let iterations = 1_000

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            data["shared"] = index
            if index.isMultiple(of: 2) {
                data["shared"] = nil
            }
        }

        XCTAssertTrue(data.keys.count <= 1)
        if let value = data["shared"] as? Int {
            XCTAssertTrue((0..<iterations).contains(value))
        }
    }

    // MARK: - HookContext integration

    func testHookContextDefaultsToFreshEmptyHookData() {
        let context: HookContext<Bool> = HookContext(
            flagKey: "flag",
            type: .boolean,
            defaultValue: false,
            ctx: nil,
            clientMetadata: nil,
            providerMetadata: nil)

        XCTAssertTrue(context.hookData.isEmpty)
    }

    func testEachHookContextGetsItsOwnHookData() {
        let first: HookContext<Bool> = HookContext(
            flagKey: "flag",
            type: .boolean,
            defaultValue: false,
            ctx: nil,
            clientMetadata: nil,
            providerMetadata: nil)
        let second: HookContext<Bool> = HookContext(
            flagKey: "flag",
            type: .boolean,
            defaultValue: false,
            ctx: nil,
            clientMetadata: nil,
            providerMetadata: nil)

        first.hookData["key"] = "value"

        XCTAssertFalse(first.hookData === second.hookData)
        XCTAssertNil(second.hookData["key"])
    }

    func testHookContextCopiesShareTheSameHookData() {
        let original: HookContext<Bool> = HookContext(
            flagKey: "flag",
            type: .boolean,
            defaultValue: false,
            ctx: nil,
            clientMetadata: nil,
            providerMetadata: nil)
        let copy = original

        copy.hookData["key"] = "value"

        XCTAssertTrue(original.hookData === copy.hookData)
        XCTAssertEqual(original.hookData["key"] as? String, "value")
    }

    func testHookContextAcceptsExplicitHookData() {
        let data = HookData()
        data["preset"] = true
        let context: HookContext<Bool> = HookContext(
            flagKey: "flag",
            type: .boolean,
            defaultValue: false,
            ctx: nil,
            clientMetadata: nil,
            providerMetadata: nil,
            hookData: data)

        XCTAssertTrue(context.hookData === data)
        XCTAssertEqual(context.hookData["preset"] as? Bool, true)
    }
}
