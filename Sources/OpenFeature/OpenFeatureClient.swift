import Foundation
import Logging

/// Metadata for when no provider is set
struct NoProviderMetadata: ProviderMetadata {
    var name: String? { nil }
}

public class OpenFeatureClient: Client {
    private var openFeatureApi: OpenFeatureAPI
    private(set) var name: String?
    private(set) var version: String?

    private(set) public var metadata: ClientMetadata
    private var hookSupport = HookSupport()

    // Lock protects concurrent access to hooks and logger
    private let lock = NSLock()
    private(set) public var hooks: [any Hook] = []
    private var logger: Logger?

    public init(openFeatureApi: OpenFeatureAPI, name: String?, version: String?) {
        self.openFeatureApi = openFeatureApi
        self.name = name
        self.version = version
        self.metadata = Metadata(name: name)
    }

    public func addHooks(_ hooks: any Hook...) {
        lock.lock()
        self.hooks.append(contentsOf: hooks)
        lock.unlock()
    }

    public func setLogger(_ logger: Logger?) {
        lock.lock()
        self.logger = logger
        lock.unlock()
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
        let state = openFeatureApi.getState()
        let options = options ?? FlagEvaluationOptions(hooks: [], hookHints: [:])
        let hints = options.hookHints
        let context = state.evaluationContext

        lock.lock()
        let clientLogger = self.logger
        let clientHooks = self.hooks
        lock.unlock()

        // Resolve logger with priority: evaluation options > client > API
        let resolvedLogger = options.logger ?? clientLogger ?? state.logger

        let provider = state.provider
        let providerHooks = provider?.hooks ?? []
        let providerMetadata = provider?.metadata ?? NoProviderMetadata()
        let mergedHooks = providerHooks + options.hooks + clientHooks + state.hooks

        let hookCtx = HookContext(
            flagKey: key,
            type: T.flagValueType,
            defaultValue: defaultValue,
            ctx: context,
            clientMetadata: self.metadata,
            providerMetadata: providerMetadata)
        var details = FlagEvaluationDetails(flagKey: key, value: defaultValue)

        do {
            hookSupport.beforeHooks(flagValueType: T.flagValueType, hookCtx: hookCtx, hooks: mergedHooks, hints: hints)

            guard let provider = provider else {
                throw OpenFeatureError.providerNotReadyError
            }

            let providerEval = try createProviderEvaluation(
                key: key,
                context: context,
                defaultValue: defaultValue,
                provider: provider,
                logger: resolvedLogger)

            details = FlagEvaluationDetails<T>.from(providerEval: providerEval, flagKey: key)
            try hookSupport.afterHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookCtx,
                details: details,
                hooks: mergedHooks,
                hints: hints)
        } catch {
            resolvedLogger?.error("Unable to correctly evaluate flag with key \(key) due to exception \(error)")
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
        hookSupport.finallyHooks(
            flagValueType: T.flagValueType, hookCtx: hookCtx, details: details, hooks: mergedHooks, hints: hints)
        return details
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func createProviderEvaluation<V: AllowedFlagValueType>(
        key: String,
        context: EvaluationContext?,
        defaultValue: V,
        provider: FeatureProvider,
        logger: Logger?
    ) throws -> ProviderEvaluation<V> {
        switch V.flagValueType {
        case .boolean:
            guard let defaultValue = defaultValue as? Bool else {
                break
            }

            if let evaluation = try provider.getBooleanEvaluation(
                key: key,
                defaultValue: defaultValue,
                context: context,
                logger: logger) as? ProviderEvaluation<V>
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
                context: context,
                logger: logger) as? ProviderEvaluation<V>
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
                context: context,
                logger: logger) as? ProviderEvaluation<V>
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
                context: context,
                logger: logger) as? ProviderEvaluation<V>
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
                context: context,
                logger: logger) as? ProviderEvaluation<V>
            {
                return evaluation
            }
        }

        throw OpenFeatureError.generalError(message: "Unable to match default value type with flag value type")
    }
}

// MARK: - Tracking

extension OpenFeatureClient {
    public func track(key: String) {
        reportTrack(key: key, context: nil, details: nil)
    }

    public func track(key: String, context: any EvaluationContext) {
        reportTrack(key: key, context: context, details: nil)
    }

    public func track(key: String, details: any TrackingEventDetails) {
        reportTrack(key: key, context: nil, details: details)
    }

    public func track(key: String, context: any EvaluationContext, details: any TrackingEventDetails) {
        reportTrack(key: key, context: context, details: details)
    }

    private func reportTrack(key: String, context: (any EvaluationContext)?, details: (any TrackingEventDetails)?) {
        let state = openFeatureApi.getState()
        do {
            try state.provider?.track(key: key, context: mergeEvaluationContext(context), details: details)
        } catch {
            let logger = lock.withLock { self.logger } ?? state.logger
            logger?.error("Unable to report track event with key \(key) due to exception \(error)")
        }
    }
}

extension OpenFeatureClient {
    func mergeEvaluationContext(_ invocationContext: (any EvaluationContext)?) -> (any EvaluationContext)? {
        let apiContext = OpenFeatureAPI.shared.getEvaluationContext()
        return mergeContextMaps(apiContext, invocationContext)
    }

    private func mergeContextMaps(_ contexts: (any EvaluationContext)?...) -> (any EvaluationContext)? {
        let validContexts = contexts.compactMap { $0 }
        guard !validContexts.isEmpty else { return nil }

        return validContexts.reduce(ImmutableContext()) { merged, next in
            let newTargetingKey = next.getTargetingKey()
            let targetingKey = newTargetingKey.isEmpty ? merged.getTargetingKey() : newTargetingKey
            let attributes = merged.asMap().merging(next.asMap()) { _, newKey in newKey }
            return ImmutableContext(targetingKey: targetingKey, structure: ImmutableStructure(attributes: attributes))
        }
    }
}
