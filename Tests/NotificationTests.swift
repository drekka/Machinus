//
//  Created by Derek Clarkson on 4/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import Machinus
import Nimble
import XCTest

class NotificationTests: XCTestCase {

    private var stateA: StateConfig<TestState> = StateConfig(.aaa, canTransitionTo: .bbb)
    private var stateB: StateConfig<TestState> = StateConfig(.bbb)
    private var stateC: StateConfig<TestState> = StateConfig(.ccc) // Because machines must have 3 states.

    private var machine: StateMachine<TestState>!
    private var observer: Any?

    override func tearDown() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        super.tearDown()
    }

    override func setUp() async throws {

        try await super.setUp()

        machine = try await StateMachine {
            stateA
            stateB
            stateC
        }
    }

    func testWatchingStateChanges() async throws {

        var observedMachine: StateMachine<TestState>?
        var fromState: TestState?
        var toState: TestState?
        observer = NotificationCenter.default.addStateChangeObserver { (sm: StateMachine<TestState>, from: TestState, to: TestState) in
            observedMachine = sm
            fromState = from
            toState = to
        }

        await machine.postNotifications(true)
        await machine.transition(to: .bbb)

        await expect(observedMachine).toEventuallyNot(beNil())

        expect(observedMachine) === machine
        expect(fromState) == .aaa
        expect(toState) == .bbb
    }
}
