import Combine
import Foundation

/// A provider that combines multiple providers into a single provider.
public class MultiProvider: FeatureProvider {
    public var hooks: [any Hook] {
        []
    }

    public static let name = "MultiProvider"
    public var metadata: ProviderMetadata

    private let providers: [FeatureProvider]
    private let strategy: Strategy

    /// Initialize a MultiProvider with a list of providers and a strategy.
    /// - Parameters:
    ///   - providers: A list of providers to evaluate.
    ///   - strategy: A strategy to evaluate the providers. Defaults to FirstFoundStrategy.
    public init(
        providers: [FeatureProvider],
        strategy: Strategy = FirstFoundStrategy()
    ) {
        self.providers = providers
        self.strategy = strategy
        self.metadata = MultiProviderMetadata(providers: providers)
    }

    public func initialize(initialContext: EvaluationContext?) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    try await provider.initialize(initialContext: initialContext)
                }
            }
            try await group.waitForAll()
        }
    }

    public func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    try await provider.onContextSet(oldContext: oldContext, newContext: newContext)
                }
            }
            try await group.waitForAll()
        }
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            return provider.getBooleanEvaluation(key:defaultValue:context:)
        }
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            return provider.getStringEvaluation(key:defaultValue:context:)
        }
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            return provider.getIntegerEvaluation(key:defaultValue:context:)
        }
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            return provider.getDoubleEvaluation(key:defaultValue:context:)
        }
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            return provider.getObjectEvaluation(key:defaultValue:context:)
        }
    }

    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        return Publishers.MergeMany(providers.map { $0.observe() }).eraseToAnyPublisher()
    }

    public struct MultiProviderMetadata: ProviderMetadata {
        public var name: String?
        
        init(providers: [FeatureProvider]) {
            self.name = providers.map({
                $0.metadata.name ?? "MultiProvider"
            }).joined(separator: ", ")
        }
    }
}
