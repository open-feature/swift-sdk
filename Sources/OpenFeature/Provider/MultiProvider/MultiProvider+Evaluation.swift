import Foundation
import Logging

// MARK: - Logger-Enabled Evaluation Methods
extension MultiProvider {
    public func getBooleanEvaluation(
        key: String,
        defaultValue: Bool,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Bool> {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { [self] (key: String, defaultValue: Bool, context: EvaluationContext?) throws
                -> ProviderEvaluation<Bool> in
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getBooleanEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
            }
        }
    }

    public func getStringEvaluation(
        key: String,
        defaultValue: String,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<String> {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { [self] (key: String, defaultValue: String, context: EvaluationContext?) throws
                -> ProviderEvaluation<String> in
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getStringEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
            }
        }
    }

    public func getIntegerEvaluation(
        key: String,
        defaultValue: Int64,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Int64> {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { [self] (key: String, defaultValue: Int64, context: EvaluationContext?) throws
                -> ProviderEvaluation<Int64> in
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getIntegerEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
            }
        }
    }

    public func getDoubleEvaluation(
        key: String,
        defaultValue: Double,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Double> {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { [self] (key: String, defaultValue: Double, context: EvaluationContext?) throws
                -> ProviderEvaluation<Double> in
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getDoubleEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
            }
        }
    }

    public func getObjectEvaluation(
        key: String,
        defaultValue: Value,
        context: EvaluationContext?,
        logger: Logger?
    ) throws -> ProviderEvaluation<Value> {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { [self] (key: String, defaultValue: Value, context: EvaluationContext?) throws
                -> ProviderEvaluation<Value> in
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getObjectEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
            }
        }
    }
}
