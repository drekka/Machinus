//
//  File.swift
//
//
//  Created by Derek Clarkson on 15/12/2022.
//

import Foundation
import Machinus
import Nimble
import XCTest

class StateAsyncSequenceTests: XCTestCase {



    func testProducesSequence() async throws {

        let logger = LogActor()

        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb, canTransitionTo: .ccc)
            StateConfig<TestState>(.ccc, canTransitionTo: .aaa)
        }

        // Async watch the transitions.
        let t = Task.detached(priority: .background) {
            for try await state in machine.stateSequence {
                await logger.append("\(String(describing:state))")
            }
        }

        // Execute. The sleeps appear to be required here to allow the async sequence background task to do it's thing
        // without dropping any values.
        try await machine.transition(to: .bbb)
        await machine.waitFor(state: .bbb)

        try await Task.sleep(for: .milliseconds(100))

        try await machine.transition(to: .ccc)
        await machine.waitFor(state: .ccc)

        try await Task.sleep(for: .milliseconds(100))

        try await machine.transition(to: .aaa)
        await machine.waitFor(state: .aaa)

        try await Task.sleep(for: .milliseconds(100))

        // Don't forget to cancel.
        t.cancel()

        await expect({ await logger.entries}) == ["aaa", "bbb", "ccc", "aaa"]
    }

}
