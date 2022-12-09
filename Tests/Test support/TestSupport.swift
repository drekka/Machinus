//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
@testable import Machinus
import Nimble
import os
import XCTest

enum TestState: StateIdentifier {
    case aaa
    case bbb
    case ccc
    case background
    case final
    case global
}

/// Used to log messages across concurrency domains.
actor LogActor {
    var entries: [String] = []
    func append(_ value: String) {
        entries.append(value)
    }
}

/// Used to flag an event across concurrency domains.
actor WaitFlagActor {
    var flag = false
    func set() {
        flag = true
    }
}

extension Machine {

    func testReset(file: StaticString = #file, line: UInt = #line,
                   to desiredState: S) async {
        let previousState = await state
        await action(file: file, line: line) { completed in
            await self.reset { _, result in
                result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: desiredState)
                completed()
            }
        }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S) async {
        let previousState = await state
        await action(file: file, line: line) { completed in
            await self.transition(to: desiredState) { machine, result in
                await expect(file: file, line: line, { await machine.state }) == desiredState
                result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: desiredState)
                completed()
            }
        }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S,
                        redirectsTo finalState: S) async {
        let previousState = await state
        await action(file: file, line: line) { completed in
            await self.transition(to: desiredState) { machine, result in
                await expect(file: file, line: line, { await machine.state }) == finalState
                result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: finalState)
                completed()
            }
        }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S,
                        failsWith expectedError: StateMachineError<S>) async {
        await action(file: file, line: line) { completed in
            await self.transition(to: desiredState) { _, result in
                result.validateFailure(file: file, line: line, with: expectedError)
                completed()
            }
        }
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line,
                               to desiredState: S) async {
        let previousState = await state
        await action(file: file, line: line) { completed in
            await self.transition { machine, result in
                await expect(file: file, line: line, { await machine.state }) == desiredState
                result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: desiredState)
                completed()
            }
        }
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line,
                               failsWith expectedError: StateMachineError<S>) async {
        await action(file: file, line: line) { completed in
            await self.transition { _, result in
                result.validateFailure(file: file, line: line, with: expectedError)
                completed()
            }
        }
    }

    private func action(file _: StaticString = #file, line _: UInt = #line,
                        queuedAction action: @escaping (@escaping () -> Void) async -> Void) async where S: StateIdentifier {
        let exp = XCTestExpectation(description: "Machine action")
        try? await Task.sleep(for: .milliseconds(100)) // Allow for back pressure with a slight pause.
        await action { exp.fulfill() }
        let waiter = XCTWaiter()
        waiter.wait(for: [exp], timeout: 5.0)
    }
}

private extension Result {

    func validateSuccessful<S>(file: StaticString, line: UInt, transitionFrom fromState: S, to toState: S) where S: StateIdentifier, Success == (from: S, to: S), Failure == StateMachineError<S> {
        switch self {
        case .failure(let error):
            fail("Transition failure: \(error)", file: file, line: line)
        case .success(let change):
            if change.from != fromState || change.to != toState {
                fail("Expected to transition \(fromState) -> \(toState), got \(change.from) -> \(change.to) instead", file: file, line: line)
            }
        }
    }

    func validateFailure<S>(file: StaticString, line: UInt,
                            with expectedError: StateMachineError<S>) where S: StateIdentifier, Success == (from: S, to: S), Failure == StateMachineError<S> {
        switch self {
        case .failure(let error) where error == expectedError:
            break // This is good.
        case .failure(let error):
            fail("Unexpected transition failure: \(error)", file: file, line: line)
        case .success:
            fail("Expected transition to fail", file: file, line: line)
        }
    }
}

extension XCTestCase {

    /// Waits for an assertion to come true.
    ///
    /// This version of wait polls the assertion periodically and ``Task.sleep(...)`` in between. This is an alternative to
    /// a `XCTest` expectation which can tie up the thread the code is working on.
    func waitFor(file: StaticString = #file, line: UInt = #line,
                 for seconds: Int = 5,
                 polling poll: Int = 100,
                 message: String = "Expression failed",
                 _ assertion: @autoclosure () async -> Bool) async {
        for _ in 1 ... (seconds * 1000 / poll) where !(await assertion()) {
            print("polling")
            try? await Task.sleep(for: .milliseconds(poll))
        }
        if !(await assertion()) {
            fail(message, file: file, line: line)
        }
    }
}
