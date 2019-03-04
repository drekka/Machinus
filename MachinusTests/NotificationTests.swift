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

        var receivedNotification: Notification?
        self.expectation(forNotification: .stateChange, object: nil) { notification in
            receivedNotification = notification
            return true
        }

        self.machine!.postNotifications = true
        self.machine!.transition(toState: .bbb) { _, error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 3.0)

        expect(receivedNotification).toNot(beNil())
        if let data:(machine: Machinus<MyState>, fromState: MyState, toState: MyState) = receivedNotification!.stateChangeInfo() {
            expect(data.machine) === machine
            expect(data.fromState) == .aaa
            expect(data.toState) == .bbb
        }
    }

}
