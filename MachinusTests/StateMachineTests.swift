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
    case global
}

class StateMachineTests: XCTestCase {

    private var stateA: StateConfig<MyState>!
    private var stateB: StateConfig<MyState>!
    private var stateBBarrierResult = true
    private var stateC: StateConfig<MyState>!
    private var backgroundState: StateConfig<MyState>!
    private var finalState: StateConfig<MyState>!
    private var globalState: StateConfig<MyState>!

    private var machine: StateMachine<MyState>!

    private var didEnterA = false
    private var didExitA = false
    private var didEnterB = false
    private var didExitB = false
    private var didEnterC = false
    private var didExitC = false
    private var didEnterBackground = false
    private var didExitBAckground = false
    private var didEnterFinal = false
    private var didEnterGlobal = false
    private var didExitGlobal = false

    private var didTransition: (MyState, MyState)?

    override func setUp() {
        super.setUp()

        stateA = StateConfig(.aaa,
                             didEnter: { [weak self] _ in self?.didEnterA = true },
                             didExit: { [weak self] _ in self?.didExitA = true },
                             allowedTransitions: .bbb, .ccc, .final)
        stateB = StateConfig(.bbb,
                             didEnter: { [weak self] _ in self?.didEnterB = true },
                             didExit: { [weak self] _ in self?.didExitB = true },
                             transitionBarrier: { self.stateBBarrierResult })
        stateC = StateConfig(.ccc,
                             didEnter: { [weak self] _ in self?.didEnterC = true },
                             didExit: { [weak self] _ in self?.didExitC = true },
                             dynamicTransition: { .aaa },
                             allowedTransitions: .aaa)
        backgroundState = BackgroundStateConfig(.background,
                                                didEnter: { [weak self] _ in self?.didEnterBackground = true },
                                                didExit: { [weak self] _ in self?.didExitBAckground = true })
        finalState = FinalStateConfig(.final,
                                      didEnter: { [weak self] _ in self?.didEnterFinal = true })
        globalState = GlobalStateConfig(.global,
                                        didEnter: { [weak self] _ in self?.didEnterGlobal = true },
                                        didExit: { [weak self] _ in self?.didExitGlobal = true })

        machine = StateMachine(didTransition: { from, to in self.didTransition = (from, to) },
                               withStates: stateA, stateB, stateC, backgroundState, finalState, globalState)

        didTransition = nil
        didExitA = false
        didEnterA = false
        didExitB = false
        didEnterB = false
        didExitC = false
        didEnterC = false
        didEnterBackground = false
        didExitBAckground = false
        didEnterFinal = false
        didEnterGlobal = false
        didExitGlobal = false
    }

    // MARK: - Lifecycle

    func testName() {
        func hex(_ length: Int) -> String {
            return "[0-9A-Za-z]{\(length)}"
        }
        expect(self.machine.name).to(match(hex(8) + "-" + hex(4) + "-" + hex(4) + "-" + hex(4) + "-" + hex(12) + "<MyState>"))
    }

    func testInitWithDuplicateStatesGeneratesFatal() {
        expect(_ = StateMachine(withStates: self.stateA, self.stateB, self.stateA)).to(throwAssertion())
        let stateAA = StateConfig<MyState>(.aaa)
        expect(_ = StateMachine(withStates: self.stateA, self.stateB, self.stateC, stateAA)).to(throwAssertion())
    }

    func testInitWithMultipleBackgroundStatesgeneratesFatal() {
        let otherBackgroundState = BackgroundStateConfig<MyState>(.ccc)
        expect(_ = StateMachine(withStates: self.stateA, self.backgroundState, otherBackgroundState)).to(throwAssertion())
    }

    func testReset() {
        machine.transition(to: .bbb)
        expect(self.machine.state).toEventually(equal(.bbb))

        machine.reset()

        expect(self.machine.state) == .aaa
    }

    // MARK: - Transitions

    func testTransitionExecution() {

        machine.transition(to: .bbb)
        expect(self.machine.state).toEventually(equal(.bbb))

        expect(self.didTransition) == (.aaa, .bbb)
        expect(self.didEnterA) == false
        expect(self.didExitA) == true
        expect(self.didEnterB) == true
        expect(self.didExitB) == false
    }

    func testSameStateTransitionGeneratesError() {
        var completed = false
        machine.transition(to: .aaa) { result in
            expect(result).to(beFailure {
                expect($0).to(matchError(StateMachineError.alreadyInState))
            })
            completed = true
        }
        expect(completed).toEventually(beTrue())
    }

    func testTransitionToUnlistedStateGeneratesError() {
        machine.transition(to: .ccc)
        expect(self.machine.state).toEventually(equal(.ccc))

        var completed = false
        machine.transition(to: .bbb) { result in
            expect(result).to(beFailure {
                expect($0).to(matchError(StateMachineError.illegalTransition))
                completed = true
            })
        }
        expect(completed).toEventually(beTrue())
    }

    func testTransitionBarrierGeneratesError() {
        var completed = false
        stateBBarrierResult = false
        machine.transition(to: .bbb) { result in
            expect(result).to(beFailure { error in
                expect(error).to(matchError(StateMachineError.transitionDenied))
            })
            completed = true
        }
        expect(completed).toEventually(beTrue())
    }
    
    func testTransitionFromFinalGeneratesError() {
        
        machine.transition(to: .final)
        expect(self.machine.state).toEventually(equal(.final))
        
        var completed = false
        machine.transition(to: .aaa) { result in
            expect(result).to(beFailure {
                expect($0).to(matchError(StateMachineError.finalState))
            })
            completed = true
        }
        expect(completed).toEventually(beTrue())
    }
    
    // MARK: - Dynamic transitions

    func testDynamicTransition() {

        machine.transition(to: .ccc)
        expect(self.machine.state).toEventually(equal(.ccc))

        machine.transition()
        expect(self.machine.state).toEventually(equal(.aaa))
    }

    func testDynamicTransitionNotDefinedFailure() {
        expect(self.machine.transition()).toEventually(throwAssertion())
    }

    // MARK: - Background transitions

    func testMachineGoesIntoBackground() {

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
        expect(self.machine.state).toEventually(equal(.background), timeout: DispatchTimeInterval.seconds(5))

        expect(self.didExitA) == false
        expect(self.didEnterBackground) == true
        expect(self.didTransition).to(beNil())
    }

    func testMachineGoesIntoForeground() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
        expect(self.machine.state).toEventually(equal(.background))

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)
        expect(self.machine.state).toEventually(equal(.aaa))

        expect(self.didExitA) == false
        expect(self.didEnterA) == false
        expect(self.didEnterBackground) == true
        expect(self.didExitBAckground) == true
        expect(self.didTransition).to(beNil())
    }

    // MARK: - Final states
}
