import Foundation

/// Holds client metadata and hook hints for provider-level hook execution within MultiProvider.
///
/// - Note: This context is stored via `@TaskLocal` and is automatically populated when evaluations
///   are performed through `OpenFeatureClient`. When `MultiProvider` is used directly (not through
///   a client), `clientMetadata` will be `nil` and `hints` will default to `[:]`. Provider hooks
///   will still execute but without client metadata or invocation hints in those scenarios.
struct ProviderHookExecutionContext: @unchecked Sendable {
    let clientMetadata: ClientMetadata?
    let hints: [String: Any]
}

enum ProviderHookExecutionContextStorage {
    @TaskLocal static var current: ProviderHookExecutionContext?
}
