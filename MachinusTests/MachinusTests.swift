//
//  MachinusTests.swift
//  MachinusTests
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

private enum MyState: StateIdentifier {
    case aaa
    case bbb
    case ccc
    case xxx
    case background
    case final
}

private func == (expectation: Nimble.Expectation<(MyState, MyState)>, toMatch: (MyState, MyState)?) {
    var actual: (MyState, MyState)?

    do {
        actual = try expectation.expression.evaluate()
    } catch {
        expectation.verify(false, FailureMessage(stringValue: "Exception thrown \(error)"))
    }

    var actualDesc = "nil"
    if let actual = actual {
        actualDesc = "(\(String(describing: actual.0)), \(String(describing: actual.1)))"
    }
    var expectedDesc = "nil"
    if let toMatch = toMatch {
        expectedDesc = "(\(String(describing: toMatch.0)), \(String(describing: toMatch.1)))"
    }

    expectation.verify(actual?.0 == toMatch?.0 && actual?.1 == toMatch?.1, FailureMessage(stringValue: "expected \(expectedDesc), got <\(actualDesc)>"))
}

class MachinusTests: XCTestCase {
    private var stateA: StateConfig<MyState>!
    private var stateB: StateConfig<MyState>!
    private var stateC: StateConfig<MyState>!
    private var backgroundState: StateConfig<MyState>!
    private var finalState: StateConfig<MyState>!

    private var machine: Machinus<MyState>!

    private var beforeTransition: (MyState, MyState)?

    private var fromStateBeforeLeaving: MyState?
    private var fromStateAfterLeaving: MyState?
    private var toStateBeforeEntering: MyState?
    private var toStateAfterEntering: MyState?

    private var afterTransition: (MyState, MyState)?

    private let notificationCenter = NotificationCenter()

    override func setUp() {
        super.setUp()

        stateA = StateConfig(identifier: .aaa, allowedTransitions: .bbb, .final)
        stateB = StateConfig(identifier: .bbb)
        stateC = StateConfig(identifier: .ccc)
        backgroundState = StateConfig(identifier: .background)
        finalState = StateConfig(identifier: .final).makeFinal()

        machine = Machinus(withStates: stateA, stateB, stateC, backgroundState, finalState)
        machine.notificationCenter = notificationCenter
        machine.backgroundState = .background
        [stateA, stateB, stateC, backgroundState].forEach {
            $0.beforeLeaving { self.fromStateBeforeLeaving = $0 }
                .afterLeaving {
                    self.fromStateAfterLeaving = $0
                }
                .beforeEntering { self.toStateBeforeEntering = $0 }
                .afterEntering { self.toStateAfterEntering = $0 }
        }

        finalState
            .beforeEntering { self.toStateBeforeEntering = $0 }
            .afterEntering { self.toStateAfterEntering = $0 }

        machine
            .beforeTransition { from, to in
                self.beforeTransition = (from, to)
            }
            .afterTransition { from, to in
                self.afterTransition = (from, to)
            }

        beforeTransition = nil

        fromStateBeforeLeaving = nil
        fromStateAfterLeaving = nil
        toStateBeforeEntering = nil
        toStateAfterEntering = nil

        afterTransition = nil
    }

    // MARK: - Lifecycle

    func testName() {
        func hex(_ length: Int) -> String {
            "[0-9A-Za-z]{\(length)}"
        }
        expect(self.machine.name).to(match(hex(8) + "-" + hex(4) + "-" + hex(4) + "-" + hex(4) + "-" + hex(12) + "<MyState>"))
    }

    func testInitDetectsDuplicateStates() {
        let stateAA = StateConfig<MyState>(identifier: .aaa)
        expect(_ = Machinus(withStates: self.stateA, self.stateB, self.stateC, stateAA)).to(throwAssertion())
    }

    func testReset() {
        machine.testSet(toState: .bbb)
        machine.reset()
        expect(self.machine.state) == .aaa

        expect(self.beforeTransition).to(beNil())
        expect(self.fromStateBeforeLeaving).to(beNil())
        expect(self.fromStateAfterLeaving).to(beNil())
        expect(self.toStateBeforeEntering).to(beNil())
        expect(self.toStateAfterEntering).to(beNil())
        expect(self.afterTransition).to(beNil())
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

        expect(self.beforeTransition) == (.aaa, .bbb)
        expect(self.fromStateBeforeLeaving) == .bbb
        expect(self.fromStateAfterLeaving) == .bbb
        expect(self.toStateBeforeEntering) == .aaa
        expect(self.toStateAfterEntering) == .aaa
        expect(self.afterTransition) == (.aaa, .bbb)
    }

    func testSameStateTransition() {
        var completed = false

        machine
            .transition(toState: .aaa) { previousState, error in
                expect(previousState).to(beNil())
                expect(error).to(beNil())
                completed = true
            }

        expect(completed).toEventually(beTrue())

        expect(self.beforeTransition).to(beNil())
        expect(self.fromStateBeforeLeaving).to(beNil())
        expect(self.fromStateAfterLeaving).to(beNil())
        expect(self.toStateBeforeEntering).to(beNil())
        expect(self.toStateAfterEntering).to(beNil())
        expect(self.afterTransition).to(beNil())
    }

    func testSameStateTransitionWhenSameStateAsError() {
        var completed = false

        machine.enableSameStateError = true
        machine
            .transition(toState: .aaa) { previousState, error in
                expect(previousState).to(beNil())
                expect(error as? MachinusError).to(equal(.alreadyInState))
                completed = true
            }

        expect(completed).toEventually(beTrue())
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
        stateB.withTransitionBarrier { false }
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

    // MARK: - Dynamic transitions

    func testDynamicTransition() {
        stateA.withDynamicTransitions {
            .bbb
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
        expect(self.machine.transition { _, _ in }).toEventually(throwAssertion())
    }

    // MARK: - Background transitions

    func testBackgroundStateMustBeKnown() {
        expect(self.machine.backgroundState = .xxx).to(throwAssertion())
    }

    func testMachineGoesIntoBackground() {
        machine.testSet(toState: .bbb)

        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: self)
        expect(self.machine.state).toEventually(equal(.background))

        expect(self.beforeTransition).to(beNil())
        expect(self.fromStateBeforeLeaving).to(beNil())
        expect(self.fromStateAfterLeaving).to(beNil())
        expect(self.toStateBeforeEntering) == .bbb
        expect(self.toStateAfterEntering) == .bbb
        expect(self.afterTransition).to(beNil())
    }

    func testMachineGoesIntoForeground() {
        machine.testSet(toState: .bbb)
        machine.testSetBackground()

        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: self)
        expect(self.machine.state).toEventually(equal(.bbb))

        expect(self.beforeTransition).to(beNil())
        expect(self.fromStateBeforeLeaving) == .bbb
        expect(self.fromStateAfterLeaving) == .bbb
        expect(self.toStateBeforeEntering).to(beNil())
        expect(self.toStateAfterEntering).to(beNil())
        expect(self.afterTransition).to(beNil())
    }

    // MARK: - Final states

    func testFinalStateCannotBeBackgroundState() {
        expect(self.machine.backgroundState = .final).to(throwAssertion())
    }

    func testFinalStateSilentyNOPs() {
        machine.testSet(toState: .final)
        var called = false
        machine.transition(toState: .aaa) { result, error in
            called = true
            expect(result).to(beNil())
            expect(error).to(beNil())
        }

        expect(called).toEventually(beTrue())
    }

    func testFinalStateThrows() {
        machine.testSet(toState: .final)
        machine.enableFinalStateTransitionError = true
        var called = false
        machine.transition(toState: .aaa) { result, error in
            called = true
            expect(result).to(beNil())
            expect(error as? MachinusError) == MachinusError.finalState
        }

        expect(called).toEventually(beTrue())
    }
}
