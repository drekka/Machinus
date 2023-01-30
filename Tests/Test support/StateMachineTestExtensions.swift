//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
@testable import Machinus
import Nimble
import XCTest


extension StateMachine where S: StateIdentifier {

    // MARK: - Convenience test functions

    func testResets(file: StaticString = #file, line: UInt = #line, to initialState: S) async {
        await waitFor(file: file, line: line, publisher: $state.eraseToAnyPublisher(), toProduce: initialState) { self.reset() }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line, to desiredState: S) async {
        await waitFor(file: file, line: line, publisher: $state.eraseToAnyPublisher(), toProduce: desiredState) { self.transition(to: desiredState) }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line, to desiredState: S, failsWith expectedError: StateMachineError<S>) async {
        await waitFor(file: file, line: line, publisher: $error.eraseToAnyPublisher(), toProduce: expectedError) { self.transition(to: desiredState) }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line, to desiredState: S, redirectsTo finalState: S) async {
        await waitFor(file: file, line: line, publisher: $state.eraseToAnyPublisher(), toProduce: finalState) { self.transition(to: desiredState) }
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line, to desiredState: S) async {
        await waitFor(file: file, line: line, publisher: $state.eraseToAnyPublisher(), toProduce: desiredState) { self.transition() }
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line, failsWith expectedError: StateMachineError<S>) async {
        await waitFor(file: file, line: line, publisher: $error.eraseToAnyPublisher(), toProduce: expectedError) { self.transition() }
    }

    // MARK: - Core test functions

    func waitFor<T>(file: StaticString = #file, line: UInt = #line,
                    publisher: AnyPublisher<T, Never>,
                    toProduce expectedValue: T,
                    using transition: @escaping () -> Void,
                    seconds: Double = 5.0) async where T: Equatable {

        // Wait until the engine enters the state or we time out.
        var cancellable: AnyCancellable?
        await withCheckedContinuation { success in
            cancellable = publisher.filter {
                // Ignore anything that's not the value we want.
                print("🫥 Received \($0)")
                return $0 == expectedValue
            }
            .timeout(.seconds(seconds), scheduler: DispatchQueue.main)
            .sink { _ in
                if let error = expectedValue as? StateMachineError<S>?, let error {
                    fail("Timeout waiting \(seconds) for StateMachineError.\(error).", file: file, line: line)
                } else {
                    fail("Timeout waiting \(seconds) for \(expectedValue).", file: file, line: line)
                }
                success.resume()
            }
                receiveValue: { _ in
                    // Got our value.
                success.resume()
            }

            // trigger the change.
            transition()
        }

        cancellable?.cancel()
    }
}
