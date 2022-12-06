//
//  Created by Derek Clarkson on 4/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import Machinus
import Nimble
import XCTest

class NotificationTests: XCTestCase {

    private var stateA: StateConfig<MyState> = StateConfig(.aaa, canTransitionTo: .bbb)
    private var stateB: StateConfig<MyState> = StateConfig(.bbb)
    private var stateC: StateConfig<MyState> = StateConfig(.ccc) // Because machines must have 3 states.

    private var machine: StateMachine<MyState>!
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

        var observedMachine: StateMachine<MyState>?
        var fromState: MyState?
        var toState: MyState?
        observer = NotificationCenter.default.addStateChangeObserver { (sm: StateMachine<MyState>, from: MyState, to: MyState) in
            print("State changed")
            observedMachine = sm
            fromState = from
            toState = to
        }

        await machine.postNotifications(true)
        try await machine.transition(to: .bbb)

        await expect({ await self.machine.state}) == .bbb

        await expect(observedMachine).toEventuallyNot(beNil())
        expect(observedMachine) === machine
        expect(fromState) == .aaa
        expect(toState) == .bbb
    }
}
