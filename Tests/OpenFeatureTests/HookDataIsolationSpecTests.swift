import Combine
import Foundation
import XCTest

@testable import OpenFeature

/// Hook data is never shared between hooks (spec 4.3.2), whatever their flag value type, registration level or
/// position in the chain.
final class HookDataIsolationSpecTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.clearProviderAndWait()
        OpenFeatureAPI.shared.clearHooks()
    }

    func testHookDataIsNotSharedBetweenDifferentHooks() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var keysSeenByA: Set<String> = []
        var keysSeenByB: Set<String> = []
        let hookA = HookDataSpyHook<Bool>(
            onBefore: { $0["onlyA"] = "a" },
            onAfter: { keysSeenByA = $0.keys })
        let hookB = HookDataSpyHook<Bool>(
            onBefore: { $0["onlyB"] = "b" },
            onAfter: { keysSeenByB = $0.keys })

        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [hookA, hookB]))

        XCTAssertEqual(keysSeenByA, ["onlyA"])
        XCTAssertEqual(keysSeenByB, ["onlyB"])
        XCTAssertFalse(hookA.seenHookData[0] === hookB.seenHookData[0])
    }

    func testHookDataIsIsolatedWhenHooksOfDifferentTypesAreMixed() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var keysSeenByFirst: Set<String> = []
        var keysSeenBySecond: Set<String> = []
        let firstBoolHook = HookDataSpyHook<Bool>(
            onBefore: { $0["first"] = true },
            onFinally: { keysSeenByFirst = $0.keys })
        let intHook = HookDataSpyHook<Int64>()
        intHook.onBefore = { $0["int"] = true }
        let secondBoolHook = HookDataSpyHook<Bool>(
            onBefore: { $0["second"] = true },
            onFinally: { keysSeenBySecond = $0.keys })

        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [firstBoolHook, intHook, secondBoolHook]))

        XCTAssertTrue(intHook.seenHookData.isEmpty)
        XCTAssertEqual(keysSeenByFirst, ["first"])
        XCTAssertEqual(keysSeenBySecond, ["second"])
        XCTAssertEqual(firstBoolHook.seenHookData.count, 3)
        XCTAssertEqual(secondBoolHook.seenHookData.count, 3)
        XCTAssertFalse(firstBoolHook.seenHookData[0] === secondBoolHook.seenHookData[0])
    }

    func testHookDataIsIsolatedAcrossRegistrationLevels() {
        var keysSeen: [String: Set<String>] = [:]
        func spy(_ level: String) -> HookDataSpyHook<Bool> {
            HookDataSpyHook<Bool>(
                onBefore: { $0[level] = true },
                onFinally: { keysSeen[level] = $0.keys })
        }
        let providerHook = spy("provider")
        let apiHook = spy("api")
        let clientHook = spy("client")
        let invocationHook = spy("invocation")

        let providerMock = HookSpecTests.NoOpProviderMock(hooks: [providerHook])
        let readyExpectation = XCTestExpectation(description: "Ready")
        let eventState = OpenFeatureAPI.shared.observe().sink { event in
            if case .ready = event {
                readyExpectation.fulfill()
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: providerMock)
        wait(for: [readyExpectation], timeout: 5)
        OpenFeatureAPI.shared.addHooks(hooks: apiHook)
        let client = OpenFeatureAPI.shared.getClient()
        client.addHooks(clientHook)

        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [invocationHook]))

        XCTAssertEqual(keysSeen["provider"], ["provider"])
        XCTAssertEqual(keysSeen["api"], ["api"])
        XCTAssertEqual(keysSeen["client"], ["client"])
        XCTAssertEqual(keysSeen["invocation"], ["invocation"])
        let hooks = [providerHook, apiHook, clientHook, invocationHook]
        XCTAssertEqual(Set(hooks.map { ObjectIdentifier($0.seenHookData[0]) }).count, 4)
        XCTAssertNotNil(eventState)
    }

    func testSameHookInstanceRegisteredTwiceGetsTwoStores() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var leaked = false
        let hook = HookDataSpyHook<Bool>()
        hook.onBefore = { data in
            if data["seen"] != nil {
                leaked = true
            }
            data["seen"] = true
        }

        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [hook, hook]))

        XCTAssertFalse(leaked)
        XCTAssertEqual(hook.seenHookData.count, 6)
        XCTAssertEqual(Set(hook.seenHookData.map { ObjectIdentifier($0) }).count, 2)
    }

    func testHookDataWorksForEveryFlagValueType() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var seen: [String: String] = [:]
        let boolHook = HookDataSpyHook<Bool>(
            onBefore: { $0["v"] = "bool" },
            onFinally: { seen["bool"] = $0["v"] as? String })
        let stringHook = HookDataSpyHook<String>(
            onBefore: { $0["v"] = "string" },
            onFinally: { seen["string"] = $0["v"] as? String })
        let intHook = HookDataSpyHook<Int64>(
            onBefore: { $0["v"] = "int" },
            onFinally: { seen["int"] = $0["v"] as? String })
        let doubleHook = HookDataSpyHook<Double>(
            onBefore: { $0["v"] = "double" },
            onFinally: { seen["double"] = $0["v"] as? String })
        let objectHook = HookDataSpyHook<Value>(
            onBefore: { $0["v"] = "object" },
            onFinally: { seen["object"] = $0["v"] as? String })
        client.addHooks(boolHook, stringHook, intHook, doubleHook, objectHook)

        _ = client.getValue(key: "key", defaultValue: false)
        _ = client.getValue(key: "key", defaultValue: "")
        _ = client.getValue(key: "key", defaultValue: Int64(0))
        _ = client.getValue(key: "key", defaultValue: 0.0)
        _ = client.getValue(key: "key", defaultValue: Value.null)

        let expected = [
            "bool": "bool",
            "string": "string",
            "int": "int",
            "double": "double",
            "object": "object",
        ]
        XCTAssertEqual(seen, expected)
        XCTAssertEqual(boolHook.seenHookData.count, 3)
        XCTAssertEqual(stringHook.seenHookData.count, 3)
        XCTAssertEqual(intHook.seenHookData.count, 3)
        XCTAssertEqual(doubleHook.seenHookData.count, 3)
        XCTAssertEqual(objectHook.seenHookData.count, 3)
    }
}
