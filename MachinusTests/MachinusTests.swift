//
//  MachinusTests.swift
//  MachinusTests
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import XCTest
import Nimble
@testable import Machinus

class MachinusTests: XCTestCase {

    enum MyState: StateIdentifier {
        case aaa
        case bbb
        case xxx
    }

    private var stateA: State<MyState>!
    private var stateB: State<MyState>!

    override func setUp() {
        super.setUp()

        self.stateA = State(withIdentifier: .aaa, allowedTransitions: .bbb)
        self.stateB = State(withIdentifier: .bbb)
    }

    func testInitRequiresMoreThanOneState() {
        expect(_ = Machinus(withStates: self.stateA)).to(throwAssertion())
    }

    func testInitDetectsDuplicateStates() {
        let stateAA = State<MyState>(withIdentifier: .aaa)
        expect(_ = Machinus(withStates: self.stateA, stateAA)).to(throwAssertion())
    }

    func testTransitionExecution() {

        let machine = Machinus(withStates: stateA, stateB)

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .bbb) {
            prevState = $0
            error = $1
        }

        expect(machine.state).toEventually(equal(.bbb))

        expect(prevState) == .aaa
        expect(error).to(beNil())
    }

    func testTransitionHookExecution() {

        let machine = Machinus(withStates: stateA, stateB)

        var beforeTransition: MyState?
        var beforeLeaving:MyState?
        var beforeEntering:MyState?
        var afterLeaving:MyState?
        var afterEntering:MyState?
        var afterTransition: MyState?

        stateA.beforeLeaving { beforeLeaving = $0 }
            .afterLeaving {afterLeaving = $0 }
        stateB.beforeEntering { beforeEntering = $0 }
            .afterEntering { afterEntering = $0 }

        machine
            .beforeTransition { beforeTransition = $0 }
            .afterTransition { afterTransition = $0 }
            .transition(toState: .bbb) { _, _ in }

        expect(machine.state).toEventually(equal(.bbb))

        expect(beforeTransition) == .bbb
        expect(beforeLeaving) == .bbb
        expect(beforeEntering) == .bbb
        expect(afterLeaving) == .aaa
        expect(afterEntering) == .aaa
        expect(afterTransition) == .aaa
    }

    func testTransitionExecutionIllegalTransitionError() {

        let machine = Machinus(withStates: stateA, stateB)
        machine.testSet(toState: .bbb)

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .aaa) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(MachinusError.illegalTransition))

        expect(machine.state) == .bbb
        expect(prevState).to(beNil())
    }

    func testTransitionExecutionUnknownStateError() {

        let machine = Machinus(withStates: stateA, stateB)

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .xxx) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(MachinusError.unregisteredState))

        expect(machine.state) == .aaa
        expect(prevState).to(beNil())
    }

}
