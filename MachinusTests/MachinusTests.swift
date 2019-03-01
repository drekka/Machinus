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

    // MARK: - Lifecycle

    func testName() {
        func hex(_ length: Int) -> String {
            return "[0-9A-Za-z]{\(length)}"
        }
        expect(self.machine.name).to(match(hex(8) + "-" + hex(4) + "-" + hex(4) + "-" + hex(4) + "-" + hex(12) + "<MyState>"))
    }

    func testInitDetectsDuplicateStates() {
        let stateAA = State<MyState>(withIdentifier: .aaa)
        expect(_ = Machinus(withStates: self.stateA, self.stateB, self.stateC, stateAA)).to(throwAssertion())
    }

    func testReset() {
        machine.testSet(toState: .bbb)
        machine.reset()
        expect(self.machine.state) == .aaa
    }

    // MARK: - Transitions

    func testTransitionExecution() {

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .bbb) {
            prevState = $0
            error = $1
        }

        expect(self.machine.state).toEventually(equal(.bbb))

        expect(prevState) == .aaa
        expect(error).to(beNil())
    }

    func testTransitionHookExecution() {

        var beforeTransitionFrom: MyState?
        var beforeTransitionTo: MyState?
        var beforeLeaving:MyState?
        var beforeEntering:MyState?
        var afterLeaving:MyState?
        var afterEntering:MyState?
        var afterTransitionFrom: MyState?
        var afterTransitionTo: MyState?

        stateA.beforeLeaving { beforeLeaving = $0 }
            .afterLeaving {afterLeaving = $0 }
        stateB.beforeEntering { beforeEntering = $0 }
            .afterEntering { afterEntering = $0 }

        machine
            .beforeTransition { from, to in
                beforeTransitionFrom = from
                beforeTransitionTo = to
            }
            .afterTransition { from, to in
                afterTransitionFrom = from
                afterTransitionTo = to
            }
            .transition(toState: .bbb) { _, _ in }

        expect(self.machine.state).toEventually(equal(.bbb))

        expect(beforeTransitionFrom) == .aaa
        expect(beforeTransitionTo) == .bbb
        expect(beforeLeaving) == .bbb
        expect(beforeEntering) == .aaa
        expect(afterLeaving) == .bbb
        expect(afterEntering) == .aaa
        expect(afterTransitionFrom) == .aaa
        expect(afterTransitionTo) == .bbb
    }

    func testSameStateTransition() {

        var beforeTransitionCalled = false
        var completed = false

        machine
            .beforeTransition { _, _ in beforeTransitionCalled = true }
            .transition(toState: .aaa) { previousState, error in
                expect(previousState).to(beNil())
                expect(error).to(beNil())
                completed = true
        }

        expect(completed).toEventually(beTrue())
        expect(beforeTransitionCalled).to(beFalse())
    }

    func testSameStateTransitionWhenSameStateAsError() {

        var beforeTransitionCalled = false
        var completed = false

        machine.sameStateAsError = true
        machine
            .beforeTransition { _, _ in beforeTransitionCalled = true }
            .transition(toState: .aaa) { previousState, error in
                expect(previousState).to(beNil())
                expect(error as? MachinusError).to(equal(.alreadyInState))
                completed = true
        }

        expect(completed).toEventually(beTrue())
        expect(beforeTransitionCalled).to(beFalse())
    }

    func testTransitionExecutionIllegalTransitionError() {

        machine.testSet(toState: .bbb)

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .aaa) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(.illegalTransition))

        expect(self.machine.state) == .bbb
        expect(prevState).to(beNil())
    }

    func testTransitionExecutionStateBarrierRejectsTransition() {

        stateB.withTransitionBarrier { return false }
        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .bbb) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(.transitionDenied))

        expect(self.machine.state) == .aaa
        expect(prevState).to(beNil())
    }

    func testTransitionExecutionUnknownStateError() {

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .xxx) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(.unregisteredState))

        expect(self.machine.state) == .aaa
        expect(prevState).to(beNil())
    }

    // MARK: - Dynamic transitions

    func testDynamicTransition() {

        stateA.withDynamicTransitions {
            return .bbb
        }

        var prevState: MyState?
        var error: Error?
        machine.transition {
            prevState = $0
            error = $1
        }

        expect(self.machine.state).toEventually(equal(.bbb))

        expect(prevState) == .aaa
        expect(error).to(beNil())
    }

    func testDynamicTransitionNotDefinedFailure() {

        var prevState: MyState?
        var error: Error?
        machine.transition {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(.dynamicTransitionNotDefined))
        expect(prevState).to(beNil())
    }
}
