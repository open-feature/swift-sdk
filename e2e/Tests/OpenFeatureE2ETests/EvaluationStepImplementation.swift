import CucumberSwift
import Foundation
import XCTest

/// CucumberSwift entry point.
///
/// `shouldRunWith(scenario:tags:)` is deliberately not implemented: `evaluation.feature` is tagged
/// `@deprecated`, and tag filtering only consults that method when it exists, so implementing it
/// without allowing `deprecated` would silently run zero scenarios.
extension Cucumber: @retroactive StepImplementation {
    /// Not `Bundle(for:)`: under SwiftPM the copied resources live in a sibling bundle.
    public var bundle: Bundle { .module }

    @available(
        *, deprecated,
        message: """
            Registers steps through CucumberSwift's deprecated regex API. Migrate to Regex \
            literals once the SDK's minimum platforms reach iOS 16 / macOS 13.
            """
    )
    public func setupSteps() {
        registerLifecycleHooks()
        registerProviderSteps()
        registerValueSteps()
        registerDetailsSteps()
        registerContextSteps()
        registerErrorSteps()
    }
}
