import Foundation
import OpenFeature

class BooleanHookMock: Hook {
    typealias HookValue = Bool

    public var beforeCalled = 0
    public var afterCalled = 0
    public var errorCalled = 0
    public var finallyCalled = 0

    private var prefix: String
    private var addEval: (String) -> Void

    init() {
        self.prefix = ""
        self.addEval = { _ in }
    }

    init(prefix: String, addEval: @escaping (String) -> Void) {
        self.prefix = prefix
        self.addEval = addEval
    }

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        beforeCalled += 1
        self.addEval(self.prefix.isEmpty ? "before" : "\(self.prefix) before")
    }

    func after<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any])
    {
        afterCalled += 1
        self.addEval(self.prefix.isEmpty ? "after" : "\(self.prefix) after")
    }

    func error<HookValue>(ctx: HookContext<HookValue>, error: Error, hints: [String: Any]) {
        errorCalled += 1
        self.addEval(self.prefix.isEmpty ? "error" : "\(self.prefix) error")
    }

    func finally<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        finallyCalled += 1
        self.addEval(self.prefix.isEmpty ? "finally" : "\(self.prefix) finally")
    }
}
