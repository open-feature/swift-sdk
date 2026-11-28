import OpenFeature

extension OpenFeatureAPI {
    /// Creates a new, independent `OpenFeatureAPI` instance with fully isolated state:
    /// provider, evaluation context, hooks, event handlers and logger. It shares nothing
    /// with `OpenFeatureAPI.shared` or with other isolated instances.
    ///
    /// Intended for dependency injection, multi-runtime applications and parallel test
    /// suites that each need their own configuration. Most applications should use
    /// `OpenFeatureAPI.shared`.
    ///
    /// - Note: An advanced, non-default capability (specification section 1.8, "Isolated
    ///   API Instances"): the factory lives in its own module so that creating instances
    ///   is an explicit opt-in. A provider must not be registered with more than one API
    ///   instance at the same time; when it is, the registration is rejected and logged
    ///   (spec 1.8.4). Once its owning instance shuts down or clears it, the provider
    ///   can be registered elsewhere.
    public static func isolated() -> OpenFeatureAPI {
        OpenFeatureAPI()
    }
}
