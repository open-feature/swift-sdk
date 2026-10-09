import Combine
import Foundation
import XCTest

@testable import OpenFeature

extension XCTestCase {
    /// Installs `provider` and blocks until it reports an error, so the evaluation that follows hits the error path.
    ///
    /// Keep the returned cancellable alive for as long as the test needs the subscription.
    func installProviderAndWaitForError(_ provider: FeatureProvider, timeout: TimeInterval = 5) -> AnyCancellable {
        let errorExpectation = XCTestExpectation(description: "Error")
        let eventState = provider.observe().sink { event in
            if case .error = event {
                errorExpectation.fulfill()
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [errorExpectation], timeout: timeout)
        return eventState
    }
}
