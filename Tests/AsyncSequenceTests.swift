//
//  Created by Derek Clarkson on 1/12/2022.
//

import Foundation
import Machinus
import Nimble
import XCTest

class AsyncSequenceTests: XCTestCase {

    private enum State: String, StateIdentifier {
        case first
        case second
        case third
    }

    private var machine: StateMachine<State>!

    override func setUp() async throws {

        let state1 = StateConfig<State>(.first, canTransitionTo: .second)
        let state2 = StateConfig<State>(.second, canTransitionTo: .third)
        let state3 = StateConfig<State>(.third, canTransitionTo: .first)

        machine = try await StateMachine {
            state1
            state2
            state3
        }
    }

    func testReceivingUpdates() async throws {

        var log: [State] = []

        Task {
            await machine.transition(to: .second)
            await machine.transition(to: .third)
        }

        for try await state in machine.stateSequence {
            log.append(state)
            if state == State.third {
                break
            }
        }

        expect(log) == [.first, .second, .third]
    }
}
