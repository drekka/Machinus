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

    private var machine: Machinus<MyState>!

    override func setUp() {
        super.setUp()

        self.stateA = State(withIdentifier: .aaa, allowedTransitions: .bbb)
        self.stateB = State(withIdentifier: .bbb)

        self.machine = Machinus(withStates: stateA, stateB)
    }

    // MARK: - Lifecycle

    func testName() {
        expect(self.machine.name).to(match("[0-9A-Za-z]{8}-"))
    }

    func testInitRequiresMoreThanOneState() {
        expect(_ = Machinus(withStates: self.stateA)).to(throwAssertion())
    }

    func testInitDetectsDuplicateStates() {
        let stateAA = State<MyState>(withIdentifier: .aaa)
        expect(_ = Machinus(withStates: self.stateA, stateAA)).to(throwAssertion())
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

        expect(self.machine.state).toEventually(equal(.bbb))

        expect(beforeTransition) == .bbb
        expect(beforeLeaving) == .bbb
        expect(beforeEntering) == .bbb
        expect(afterLeaving) == .aaa
        expect(afterEntering) == .aaa
        expect(afterTransition) == .aaa
    }

    func testTransitionExecutionIllegalTransitionError() {

        machine.testSet(toState: .bbb)

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .aaa) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(MachinusError.illegalTransition))

        expect(self.machine.state) == .bbb
        expect(prevState).to(beNil())
    }

    func testTransitionExecutionUnknownStateError() {

        var prevState: MyState?
        var error: Error?
        machine.transition(toState: .xxx) {
            prevState = $0
            error = $1
        }

        expect(error as? MachinusError).toEventually(equal(MachinusError.unregisteredState))

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

        expect(error as? MachinusError).toEventually(equal(MachinusError.dynamicTransitionNotDefined))
        expect(prevState).to(beNil())
    }
}
