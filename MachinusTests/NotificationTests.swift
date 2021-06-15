//
//  NotificationTests.swift
//  MachinusTests
//
//  Created by Derek Clarkson on 4/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import XCTest
import Machinus
import Nimble

class NotificationTests: XCTestCase {

    enum MyState: StateIdentifier {
        case aaa
        case bbb
        case ccc
    }

    private var stateA: StateConfig<MyState>!
    private var stateB: StateConfig<MyState>!
    private var stateC: StateConfig<MyState>! // Because machines must have 3 states.

    private var machine: StateMachine<MyState>!

    override func setUp() {
        super.setUp()

        self.stateA = StateConfig(.aaa,                 canTransitionTo: .bbb)
        self.stateB = StateConfig(.bbb)
        self.stateC = StateConfig(.ccc)

        self.machine = StateMachine(withStates: stateA, stateB, stateC)
    }

    func testWatchingStateChanges() {

        let exp = expectation(description: "Waiting for notification")
        var observer: Any?
        observer = NotificationCenter.default.addStateChangeObserver { [weak self] (sm: StateMachine<MyState>, fromState: MyState, toState: MyState) in
            NotificationCenter.default.removeObserver(observer!)
            expect(sm) === self?.machine
            expect(fromState) == .aaa
            expect(toState) == .bbb
            exp.fulfill()
        }

        self.machine!.postNotifications = true
        self.machine!.transition(to: .bbb) { result in
            if case .failure(let error) = result {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 3.0)
    }
}
