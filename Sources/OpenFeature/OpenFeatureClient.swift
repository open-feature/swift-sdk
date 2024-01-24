import Foundation
import os

public class OpenFeatureClient: Client {
    private let hookLock = NSLock()

    private var openFeatureApi: OpenFeatureAPI
    private(set) var name: String?
    private(set) var version: String?

    private(set) public var metadata: ClientMetadata
    private(set) public var hooks: [any Hook] = []

    private var hookSupport = HookSupport()
    private var logger = Logger()

    public init(openFeatureApi: OpenFeatureAPI, name: String?, version: String?) {
        self.openFeatureApi = openFeatureApi
        self.name = name
        self.version = version
        self.metadata = Metadata(name: name)
    }

    public func addHooks(_ hooks: any Hook...) {
        hookLock.lock()
        self.hooks.append(contentsOf: hooks)
        hookLock.unlock()
    }
}

extension OpenFeatureClient {
    // MARK: Generics
    public func getValue<T>(key: String, defaultValue: T) -> T where T: AllowedFlagValueType {
        getDetails(key: key, defaultValue: defaultValue).value
    }

    public func getValue<T>(key: String, defaultValue: T, options: FlagEvaluationOptions) -> T
    where T: AllowedFlagValueType {
        getDetails(key: key, defaultValue: defaultValue, options: options).value
    }

    public func getDetails<T>(key: String, defaultValue: T)
        -> FlagEvaluationDetails<T> where T: AllowedFlagValueType, T: Equatable
    {
        getDetails(key: key, defaultValue: defaultValue, options: FlagEvaluationOptions())
    }

    public func getDetails<T>(key: String, defaultValue: T, options: FlagEvaluationOptions)
        -> FlagEvaluationDetails<T> where T: AllowedFlagValueType, T: Equatable
    {
        evaluateFlag(
            key: key,
            defaultValue: defaultValue,
            options: options
        )
    }
}

extension OpenFeatureClient {
    public struct Metadata: ClientMetadata {
        public var name: String?
    }
}

extension OpenFeatureClient {
    private func evaluateFlag<T: AllowedFlagValueType>(
        key: String,
        defaultValue: T,
        options: FlagEvaluationOptions?
    ) -> FlagEvaluationDetails<T> {
        let options = options ?? FlagEvaluationOptions(hooks: [], hookHints: [:])
        let hints = options.hookHints
        let context = openFeatureApi.getEvaluationContext()

        var details = FlagEvaluationDetails(flagKey: key, value: defaultValue)
        let provider = openFeatureApi.getProvider() ?? NoOpProvider()
        let hookCtx = HookContext(
            flagKey: key,
            type: T.flagValueType,
            defaultValue: defaultValue,
            ctx: context,
            clientMetadata: self.metadata,
            providerMetadata: provider.metadata)

        hookLock.lock()
        let mergedHooks = provider.hooks + options.hooks + hooks + openFeatureApi.hooks
        hookLock.unlock()

        do {
            hookSupport.beforeHooks(flagValueType: T.flagValueType, hookCtx: hookCtx, hooks: mergedHooks, hints: hints)

            let providerEval = try createProviderEvaluation(
                key: key,
                context: context,
                defaultValue: defaultValue,
                provider: provider)

            let evalDetails = FlagEvaluationDetails<T>.from(providerEval: providerEval, flagKey: key)
            details = evalDetails

            try hookSupport.afterHooks(
                flagValueType: T.flagValueType, hookCtx: hookCtx, details: evalDetails, hooks: mergedHooks, hints: hints
            )
        } catch {
            logger.error("Unable to correctly evaluate flag with key \(key) due to exception \(error)")

            if let error = error as? OpenFeatureError {
                details.errorCode = error.errorCode()
            } else {
                details.errorCode = .general
            }

            details.errorMessage = "\(error)"
            details.reason = Reason.error.rawValue

            hookSupport.errorHooks(
                flagValueType: T.flagValueType, hookCtx: hookCtx, error: error, hooks: mergedHooks, hints: hints)
        }

        hookSupport.afterAllHooks(
            flagValueType: T.flagValueType, hookCtx: hookCtx, hooks: mergedHooks, hints: hints)

        return details
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func createProviderEvaluation<V: AllowedFlagValueType>(
        key: String,
        context: EvaluationContext?,
        defaultValue: V,
        provider: FeatureProvider
    ) throws -> ProviderEvaluation<V> {
        switch V.flagValueType {
        case .boolean:
            guard let defaultValue = defaultValue as? Bool else {
                break
            }

            if let evaluation = try provider.getBooleanEvaluation(
                key: key,
                defaultValue: defaultValue,
                context: context) as? ProviderEvaluation<V>
            {
                return evaluation
            }
        case .string:
            guard let defaultValue = defaultValue as? String else {
                break
            }

            if let evaluation = try provider.getStringEvaluation(
                key: key,
                defaultValue: defaultValue,
                context: context) as? ProviderEvaluation<V>
            {
                return evaluation
            }
        case .integer:
            guard let defaultValue = defaultValue as? Int64 else {
                break
            }

            if let evaluation = try provider.getIntegerEvaluation(
                key: key,
                defaultValue: defaultValue,
                context: context) as? ProviderEvaluation<V>
            {
                return evaluation
            }
        case .double:
            guard let defaultValue = defaultValue as? Double else {
                break
            }

            if let evaluation = try provider.getDoubleEvaluation(
                key: key,
                defaultValue: defaultValue,
                context: context) as? ProviderEvaluation<V>
            {
                return evaluation
            }
        case .object:
            guard let defaultValue = defaultValue as? Value else {
                break
            }

            if let evaluation = try provider.getObjectEvaluation(
                key: key,
                defaultValue: defaultValue,
                context: context) as? ProviderEvaluation<V>
            {
                return evaluation
            }
        }

        throw OpenFeatureError.generalError(message: "Unable to match default value type with flag value type")
    }
}
