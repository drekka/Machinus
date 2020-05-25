//
//  CombineTests.swift
//  MachinusTests
//
//  Created by Derek Clarkson on 25/5/20.
//  Copyright © 2020 Derek Clarkson. All rights reserved.
//

import XCTest
import Machinus

enum State: StateIdentifier {
    case first
    case second
    case third
}

class CombineTests: XCTestCase {

    var machine: Machinus<State>!

    override func setUp() {
        let state1 = StateConfig<State>(identifier: .first, allowedTransitions: .second)
        let state2 = StateConfig<State>(identifier: .second, allowedTransitions: .third)
        let state3 = StateConfig<State>(identifier: .third, allowedTransitions: .first)
        machine = Machinus(withStates: state1, state2, state3)
    }

    func testReceivingUpdates() {

        let initialState = self.expectation(description: "initial state")
        let firstTransition = self.expectation(description: "to second")
        let secondTransition = self.expectation(description: "to third")

        let cancellable = machine.sink { newState in
            print("Received " + String(describing: newState))
            switch newState {
            case .first:
                initialState.fulfill()
            case .second:
                firstTransition.fulfill()
            case .third:
                secondTransition.fulfill()
            }
        }

        withExtendedLifetime(cancellable) {
            machine.transition(toState: .second) { _,_ in }
            machine.transition(toState: .third) { _,_ in }

            waitForExpectations(timeout: 3.0)
        }
    }

    func testCancelling() {

        let firstTransition = self.expectation(description: "to second")

        let cancellable = machine.sink { newState in
            if newState == .second {
                firstTransition.fulfill()
            } else if newState == .third {
                XCTFail("Second transition should not be received.")
            }
        }

        withExtendedLifetime(cancellable) {
            machine.transition(toState: .second) { _,_ in }
            waitForExpectations(timeout: 3.0)

            cancellable.cancel()
            machine.transition(toState: .third) { _,_ in }
        }
    }

    func testMultipleSubscribers() {

        let firstSubscriberTransition = self.expectation(description: "1st to second")
        let secondSubscriberTransition = self.expectation(description: "2nd to second")

        let cancellables = [
            machine.sink { newState in
                if newState == .second {
                    firstSubscriberTransition.fulfill()
                }
            },
            machine.sink { newState in
                if newState == .second {
                    secondSubscriberTransition.fulfill()
                }
            }
        ]

        withExtendedLifetime(cancellables) {
            machine.transition(toState: .second) { _,_ in }
            waitForExpectations(timeout: 3.0)
        }
    }
}