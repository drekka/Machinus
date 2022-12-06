//
//  Created by Derek Clarkson on 25/5/20.
//  Copyright © 2020 Derek Clarkson. All rights reserved.
//

import Combine
import Machinus
import Nimble
import XCTest

class CombineTests: XCTestCase {

    private enum State: String, StateIdentifier {
        case first
        case second
        case third
    }

    private var machine: StateMachine<State>!
    private var state: State?
    private var cancellables: [AnyCancellable]!

    override func setUp() async throws {

        cancellables = []
        state = nil

        let state1 = StateConfig<State>(.first, canTransitionTo: .second)
        let state2 = StateConfig<State>(.second, canTransitionTo: .third)
        let state3 = StateConfig<State>(.third, canTransitionTo: .first)

        machine = try await StateMachine {
            state1
            state2
            state3
        }

        cancellables.append(
            machine.statePublisher.sink { result in
                if case .failure(let error) = result {
                    fail("Unexpected error \(error)")
                }
            }
            receiveValue: { newState in
                print("Received " + String(describing: newState))
                self.state = newState
            }
        )
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    func testReceivingUpdatesWhenStateChanges() async throws {
        await expect(self.state).toEventually(equal(.first))
        try await machine.transition(to: .second)
        await expect(self.state).toEventually(equal(.second))
        try await machine.transition(to: .third)
        await expect(self.state).toEventually(equal(.third))
    }

    func testCancellingTheSubscriptionStopsUpdates() async throws {

        await expect(self.state).toEventually(equal(.first))
        try await machine.transition(to: .second)
        await expect(self.state).toEventually(equal(.second))

        cancellables?.forEach { $0.cancel() }
        cancellables = nil

        try await machine.transition(to: .third)
        await expect(self.state).toNever(equal(.third))
    }

    func testMultipleSubscribers() async throws {

        var state1: State?
        var state2: State?

        cancellables = [
            machine.statePublisher.sink { result in
                if case .failure(let error) = result {
                    fail("Unexpected error \(error)")
                }
            }
            receiveValue: { newState in
                state1 = newState
            },
            machine.statePublisher.sink { result in
                if case .failure(let error) = result {
                    fail("Unexpected error \(error)")
                }
            }
            receiveValue: { newState in
                state2 = newState
            },
        ]

        await expect(state1).toEventually(equal(.first))
        await expect(state2).toEventually(equal(.first))

        try await machine.transition(to: .second)
        await expect(state1).toEventually(equal(.second))
        await expect(state2).toEventually(equal(.second))

        cancellables[1].cancel()

        try await machine.transition(to: .third)
        await expect(state1).toEventually(equal(.third))
        await expect(state2).toNever(equal(.third))
    }
}
