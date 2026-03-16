import Foundation

// MARK: - Per-Provider Hook Execution
extension MultiProvider {
    func evaluateWithProviderHooks<T: AllowedFlagValueType>(
        provider: FeatureProvider,
        key: String,
        defaultValue: T,
        context: EvaluationContext?,
        evaluation: () throws -> ProviderEvaluation<T>
    ) throws -> ProviderEvaluation<T> {
        let providerHooks = provider.hooks
        guard !providerHooks.isEmpty else {
            return try evaluation()
        }

        let hookExecutionContext = ProviderHookExecutionContextStorage.current
        let hookContext = HookContext(
            flagKey: key,
            type: T.flagValueType,
            defaultValue: defaultValue,
            ctx: context?.deepCopy(),
            clientMetadata: hookExecutionContext?.clientMetadata,
            providerMetadata: provider.metadata
        )
        let hints = hookExecutionContext?.hints ?? [:]
        var details = FlagEvaluationDetails(flagKey: key, value: defaultValue)

        hookSupport.beforeHooks(
            flagValueType: T.flagValueType,
            hookCtx: hookContext,
            hooks: providerHooks,
            hints: hints
        )

        defer {
            hookSupport.finallyHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookContext,
                details: details,
                hooks: providerHooks,
                hints: hints
            )
        }

        do {
            let providerEvaluation = try evaluation()
            details = FlagEvaluationDetails.from(providerEval: providerEvaluation, flagKey: key)
            try hookSupport.afterHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookContext,
                details: details,
                hooks: providerHooks,
                hints: hints
            )
            return providerEvaluation
        } catch {
            if let openFeatureError = error as? OpenFeatureError {
                details.errorCode = openFeatureError.errorCode()
            } else if details.errorCode == nil {
                details.errorCode = .general
            }
            details.errorMessage = "\(error)"
            details.reason = Reason.error.rawValue
            hookSupport.errorHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookContext,
                error: error,
                hooks: providerHooks,
                hints: hints
            )
            throw error
        }
    }
}
