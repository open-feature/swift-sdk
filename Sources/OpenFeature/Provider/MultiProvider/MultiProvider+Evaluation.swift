import Foundation
import Logging

// MARK: - Logger-Enabled Evaluation Methods
extension MultiProvider {
    func evaluateStrategy<T: AllowedFlagValueType>(
        key: String,
        defaultValue: T,
        context: EvaluationContext?,
        logger: Logger?,
        providerEvaluation: @escaping (FeatureProvider, String, T, EvaluationContext?, Logger?) throws
            -> ProviderEvaluation<T>
    ) throws -> ProviderEvaluation<T> {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { [self] (key: String, defaultValue: T, context: EvaluationContext?) throws
                -> ProviderEvaluation<T> in
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try providerEvaluation(provider, key, defaultValue, context, logger)
                }
            }
        }
    }

    public func getBooleanEvaluation(
        key: String,
        defaultValue: Bool,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Bool> {
        try evaluateStrategy(
            key: key, defaultValue: defaultValue, context: context, logger: logger
        ) { provider, key, defaultValue, context, logger in
            try provider.getBooleanEvaluation(
                key: key, defaultValue: defaultValue, context: context, logger: logger)
        }
    }

    public func getStringEvaluation(
        key: String,
        defaultValue: String,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<String> {
        try evaluateStrategy(
            key: key, defaultValue: defaultValue, context: context, logger: logger
        ) { provider, key, defaultValue, context, logger in
            try provider.getStringEvaluation(
                key: key, defaultValue: defaultValue, context: context, logger: logger)
        }
    }

    public func getIntegerEvaluation(
        key: String,
        defaultValue: Int64,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Int64> {
        try evaluateStrategy(
            key: key, defaultValue: defaultValue, context: context, logger: logger
        ) { provider, key, defaultValue, context, logger in
            try provider.getIntegerEvaluation(
                key: key, defaultValue: defaultValue, context: context, logger: logger)
        }
    }

    public func getDoubleEvaluation(
        key: String,
        defaultValue: Double,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Double> {
        try evaluateStrategy(
            key: key, defaultValue: defaultValue, context: context, logger: logger
        ) { provider, key, defaultValue, context, logger in
            try provider.getDoubleEvaluation(
                key: key, defaultValue: defaultValue, context: context, logger: logger)
        }
    }

    public func getObjectEvaluation(
        key: String,
        defaultValue: Value,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Value> {
        try evaluateStrategy(
            key: key, defaultValue: defaultValue, context: context, logger: logger
        ) { provider, key, defaultValue, context, logger in
            try provider.getObjectEvaluation(
                key: key, defaultValue: defaultValue, context: context, logger: logger)
        }
    }
}
