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
        case xxx
    }

    private var stateA: State<MyState>!
    private var stateB: State<MyState>!
    private var stateC: State<MyState>!

    private var machine: Machinus<MyState>!

    override func setUp() {
        super.setUp()

        self.stateA = State(withIdentifier: .aaa, allowedTransitions: .bbb)
        self.stateB = State(withIdentifier: .bbb)
        self.stateC = State(withIdentifier: .ccc)

        self.machine = Machinus(withStates: stateA, stateB, stateC)
    }

    func testSendingStateChangeNotification() {

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
