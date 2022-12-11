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

extension Machine {

    func testReset(file: StaticString = #file, line: UInt = #line,
                   to desiredState: S) async {
        let previousState = await state
        await reset { _, result in
            result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: desiredState)
        }
        await waitFor(file: file, line: line, await state == desiredState)
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S) async {
        let previousState = await state
        await transition(to: desiredState) { _, result in
            result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: desiredState)
        }
        await waitFor(file: file, line: line, await state == desiredState)
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S,
                        redirectsTo finalState: S) async {
        let previousState = await state
        await transition(to: desiredState) { _, result in
            result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: finalState)
        }
        await waitFor(file: file, line: line, await state == finalState)
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S,
                        failsWith expectedError: StateMachineError<S>) async {
        let finished = FlagActor()
        await transition(to: desiredState) { _, result in
            result.validateFailure(file: file, line: line, with: expectedError)
            await finished.set()
        }
        await waitFor(file: file, line: line, await finished.flag)
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line,
                               to desiredState: S) async {
        let previousState = await state
        await transition { machine, result in
            await expect(file: file, line: line, { await machine.state }) == desiredState
            result.validateSuccessful(file: file, line: line, transitionFrom: previousState, to: desiredState)
        }
        await waitFor(file: file, line: line, await state == desiredState)
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line,
                               failsWith expectedError: StateMachineError<S>) async {
        let finished = FlagActor()
        await transition { _, result in
            result.validateFailure(file: file, line: line, with: expectedError)
            await finished.set()
        }
        await waitFor(file: file, line: line, await finished.flag)
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
