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

extension Transitionable where S: Equatable {

    func testReset(file: StaticString = #file, line: UInt = #line) async {
        await testSuccessfulTransition(file: file, line: line, to: initialState.identifier) {
            try await self.reset()
        }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S) async {
        await testSuccessfulTransition(file: file, line: line, to: desiredState) {
            try await self.transition(to: desiredState)
        }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S,
                        redirectsTo finalState: S) async {
        await testSuccessfulTransition(file: file, line: line, to: finalState) {
            try await self.transition(to: desiredState)
        }
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line,
                               to desiredState: S) async {
        await testSuccessfulTransition(file: file, line: line, to: desiredState) {
            try await self.transition()
        }
    }

    private func testSuccessfulTransition(file: StaticString = #file, line: UInt = #line,
                                          to desiredState: S,
                                          using transition: () async throws -> TransitionResult<S>) async {
        let previousState = await state
        do {
            let result = try await transition()
            expect(file: file, line: line, result.from).to(equal(previousState), description: "result from state does not match")
            expect(file: file, line: line, result.to).to(equal(desiredState), description: "result to state does not match")
            await expect(file: file, line: line, { await self.state }).to(equal(desiredState), description: "machine state incorrect")
        } catch {
            fail("Unexpected transition error \(previousState) -> \(desiredState): \(error)", file: file, line: line)
        }
    }

    func testTransition(file: StaticString = #file, line: UInt = #line,
                        to desiredState: S,
                        failsWith expectedError: StateMachineError<S>) async {
        await testTransition(file: file, line: line, failsWith: expectedError) {
            try await self.transition(to: desiredState)
        }
    }

    func testDynamicTransition(file: StaticString = #file, line: UInt = #line,
                               failsWith expectedError: StateMachineError<S>) async {
        await testTransition(file: file, line: line, failsWith: expectedError) {
            try await self.transition()
        }
    }

    private func testTransition(file: StaticString = #file, line: UInt = #line,
                                failsWith expectedError: StateMachineError<S>,
                                using transition: () async throws -> TransitionResult<S>) async {
        do {
            _ = try await transition()
            fail("Error not thrown")
        } catch let error as StateMachineError<S> {
            expect(file: file, line: line, error).to(equal(expectedError), description: "incorrect error returned")
        } catch {
            fail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
