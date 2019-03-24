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

    private var machine: Machinus<MyState>!

    override func setUp() {
        super.setUp()

        self.stateA = StateConfig(identifier: .aaa, allowedTransitions: .bbb)
        self.stateB = StateConfig(identifier: .bbb)
        self.stateC = StateConfig(identifier: .ccc)

        self.machine = Machinus(withStates: stateA, stateB, stateC)
    }

    func testWatchingStateChanges() {

        let exp = expectation(description: "Waiting for notification")
        var observer: Any?
        observer = NotificationCenter.default.addStateChangeObserver { [weak self] (sm: Machinus<MyState>, fromState: MyState, toState: MyState) in
            NotificationCenter.default.removeObserver(observer!)
            expect(sm) === self?.machine
            expect(fromState) == .aaa
            expect(toState) == .bbb
            exp.fulfill()
        }

        self.machine!.postNotifications = true
        self.machine!.transition(toState: .bbb) { _, error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 3.0)
    }
}
