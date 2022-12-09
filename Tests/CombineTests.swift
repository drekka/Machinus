//
//  Created by Derek Clarkson on 25/5/20.
//  Copyright © 2020 Derek Clarkson. All rights reserved.
//

import Combine
import Machinus
import Nimble
import XCTest

class CombineTests: XCTestCase {

    private var machine: StateMachine<TestState>!
    private var states: [TestState]!
    private var cancellables: [AnyCancellable]!

    override func setUp() async throws {

        cancellables = []
        states = []

        machine = try await StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb, canTransitionTo: .ccc)
            StateConfig<TestState>(.ccc, canTransitionTo: .aaa)
        }

        cancellables.append(
            machine.statePublisher.sink { result in
                if case .failure(let error) = result {
                    fail("Unexpected error \(error)")
                }
            }
            receiveValue: { self.states.append($0)
            }
        )
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    func testReceivingUpdatesWhenStateChanges() async throws {
        await machine.testTransition(to: .bbb)
        expect(self.states) == [.aaa, .bbb]
        await machine.testTransition(to: .ccc)
        expect(self.states) == [.aaa, .bbb, .ccc]
    }

    func testCancellingTheSubscriptionStopsUpdates() async throws {

        await machine.testTransition(to: .bbb)
        expect(self.states) == [.aaa, .bbb]

        cancellables?.forEach { $0.cancel() }
        cancellables = nil

        await machine.testTransition(to: .ccc)
        expect(self.states) == [.aaa, .bbb]
    }

    func testMultipleSubscribers() async throws {

        var states1: [TestState] = []
        var states2: [TestState] = []

        cancellables = [
            machine.statePublisher.sink { result in
                if case .failure(let error) = result {
                    fail("Unexpected error \(error)")
                }
            }
            receiveValue: { states1.append($0) },
            machine.statePublisher.sink { result in
                if case .failure(let error) = result {
                    fail("Unexpected error \(error)")
                }
            }
            receiveValue: { states2.append($0) },
        ]

        await machine.testTransition(to: .bbb)
        expect(states1) == [.aaa, .bbb]
        expect(states2) == [.aaa, .bbb]

        cancellables[1].cancel()

        await machine.testTransition(to: .ccc)
        expect(states1) == [.aaa, .bbb, .ccc]
        expect(states2) == [.aaa, .bbb]
    }
}
