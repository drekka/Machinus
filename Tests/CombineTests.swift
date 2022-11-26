//
//  CombineTests.swift
//  MachinusTests
//
//  Created by Derek Clarkson on 25/5/20.
//  Copyright © 2020 Derek Clarkson. All rights reserved.
//

import Combine
import Machinus
import Nimble
import XCTest

enum State: StateIdentifier {
    case first
    case second
    case third
}

class CombineTests: XCTestCase {

    var machine: StateMachine<State>!
    var state: State?
    var cancellable: AnyCancellable?

    override func setUp() {

        state = nil
        let state1 = StateConfig<State>(.first, canTransitionTo: .second)
        let state2 = StateConfig<State>(.second, canTransitionTo: .third)
        let state3 = StateConfig<State>(.third, canTransitionTo: .first)

        machine = StateMachine(withStates: state1, state2, state3)

        cancellable = machine.sink { newState in
            print("Received " + String(describing: newState))
            self.state = newState
        }
    }

    func testReceivingUpdatesWhenStateChanges() {
        expect(self.state).toEventually(equal(.first))
        machine.transition(to: .second)
        expect(self.state).toEventually(equal(.second))
        machine.transition(to: .third)
        expect(self.state).toEventually(equal(.third))
    }

    func testCancellingTheSubscriptionStopsUpdates() {

        expect(self.state).toEventually(equal(.first))
        machine.transition(to: .second)
        expect(self.state).toEventually(equal(.second))

        cancellable?.cancel()
        cancellable = nil

        machine.transition(to: .third)
        expect(self.state).toNever(equal(.third))
    }

    func testMultipleSubscribers() {

        var state1: State?
        var state2: State?

        let cancellables = [
            machine.sink { newState in
                state1 = newState
            },
            machine.sink { newState in
                state2 = newState
            },
        ]

        expect(state1).toEventually(equal(.first))
        expect(state2).toEventually(equal(.first))

        machine.transition(to: .second)
        expect(state1).toEventually(equal(.second))
        expect(state2).toEventually(equal(.second))

        cancellables[1].cancel()
        machine.transition(to: .third)
        expect(state1).toEventually(equal(.third))
        expect(state2).toNever(equal(.third))
    }
}
