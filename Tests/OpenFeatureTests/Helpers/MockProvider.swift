import Combine
import Foundation

@testable import OpenFeature

/// A mock provider that can be used to test provider events with payloads.
/// It can be configured with a set of callbacks that will be called when the provider is initialized
class MockProvider: FeatureProvider {
    static let name = "MockProvider"
    var metadata: ProviderMetadata = MockProviderMetadata()

    var hooks: [any Hook] = []
    var throwFatal = false
    private let eventHandler = EventHandler()
    private let _onContextSet: (EvaluationContext?, EvaluationContext) async throws -> Void
    private let _initialize: (EvaluationContext?) async throws -> Void
    private let _getBooleanEvaluation: (String, Bool, EvaluationContext?) throws -> ProviderEvaluation<Bool>
    private let _getStringEvaluation: (String, String, EvaluationContext?) throws -> ProviderEvaluation<String>
    private let _getIntegerEvaluation: (String, Int64, EvaluationContext?) throws -> ProviderEvaluation<Int64>
    private let _getDoubleEvaluation: (String, Double, EvaluationContext?) throws -> ProviderEvaluation<Double>
    private let _getObjectEvaluation: (String, Value, EvaluationContext?) throws -> ProviderEvaluation<Value>
    private let _observe: () -> AnyPublisher<ProviderEvent?, Never>

    /// Initialize the provider with a set of callbacks that will be called when the provider is initialized,
    init(
        onContextSet: @escaping (EvaluationContext?, EvaluationContext) async throws -> Void = { _, _ in },
        initialize: @escaping (EvaluationContext?) async throws -> Void = { _ in },
        getBooleanEvaluation: @escaping (
            String,
            Bool,
            EvaluationContext?
        ) throws -> ProviderEvaluation<Bool> = { _, fallback, _ in
            return ProviderEvaluation(value: fallback, flagMetadata: [:])
        },
        getStringEvaluation: @escaping (
            String,
            String,
            EvaluationContext?
        ) throws -> ProviderEvaluation<String> = { _, fallback, _ in
            return ProviderEvaluation(value: fallback, flagMetadata: [:])
        },
        getIntegerEvaluation: @escaping (
            String,
            Int64,
            EvaluationContext?
        ) throws -> ProviderEvaluation<Int64> = { _, fallback, _ in
            return ProviderEvaluation(value: fallback, flagMetadata: [:])
        },
        getDoubleEvaluation: @escaping (
            String,
            Double,
            EvaluationContext?
        ) throws -> ProviderEvaluation<Double> = { _, fallback, _ in
            return ProviderEvaluation(value: fallback, flagMetadata: [:])
        },
        getObjectEvaluation: @escaping (
            String,
            Value,
            EvaluationContext?
        ) throws -> ProviderEvaluation<Value> = { _, fallback, _ in
            return ProviderEvaluation(value: fallback, flagMetadata: [:])
        },
        observe: @escaping () -> AnyPublisher<ProviderEvent?, Never> = { Just(nil).eraseToAnyPublisher() }
    ) {
        self._onContextSet = onContextSet
        self._initialize = initialize
        self._getBooleanEvaluation = getBooleanEvaluation
        self._getStringEvaluation = getStringEvaluation
        self._getIntegerEvaluation = getIntegerEvaluation
        self._getDoubleEvaluation = getDoubleEvaluation
        self._getObjectEvaluation = getObjectEvaluation
        self._observe = observe
    }

    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws {
        try await _onContextSet(oldContext, newContext)
    }

    func initialize(initialContext: EvaluationContext?) async throws {
        try await _initialize(initialContext)
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        try _getBooleanEvaluation(key, defaultValue, context)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        try _getStringEvaluation(key, defaultValue, context)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        try _getIntegerEvaluation(key, defaultValue, context)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        try _getDoubleEvaluation(key, defaultValue, context)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        try _getObjectEvaluation(key, defaultValue, context)
    }

    func observe() -> AnyPublisher<ProviderEvent?, Never> {
        _observe()
    }
}

extension MockProvider {
    struct MockProviderMetadata: ProviderMetadata {
        var name: String? = MockProvider.name
    }
}

extension MockProvider {
    enum MockProviderError: LocalizedError {
        case message(String)

        var errorDescription: String? {
            switch self {
            case .message(let message):
                return message
            }
        }
    }
}
