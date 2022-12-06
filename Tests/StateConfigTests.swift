//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

class StateConfigTests: XCTestCase {

    private var stateA: StateConfig<MyState> = StateConfig(.aaa, canTransitionTo: .bbb)
    private var stateAA: StateConfig<MyState> = StateConfig(.aaa)
    private var stateB: StateConfig<MyState> = StateConfig(.bbb)
    private var stateC: StateConfig<MyState> = StateConfig(.ccc)
    private var global: StateConfig<MyState> = StateConfig.global(.global, canTransitionTo: .aaa)
    private var final: StateConfig<MyState> = StateConfig.final(.final)

    // MARK: - Hashable

    func testHashValue() {
        expect(self.stateA.hashValue) == MyState.aaa.hashValue
    }

    // MARK: - Custom debug string convertable

    func testCustomStringConvertable() {
        expect(self.stateA.description) == ".aaa"
        expect(self.stateAA.description) == ".aaa"
        expect(self.stateB.description) == ".bbb"
    }

    // MARK: - Equatable

    func testEquatableConfigEqualsConfig() {
        expect(self.stateA == self.stateAA) == true
        expect(self.stateA == self.stateB) == false
    }

    func testEquatableStateEqualsConfig() {
        expect(MyState.aaa == self.stateA) == true
        expect(MyState.bbb == self.stateA) == false
    }

    func testEquatableConfigEqualsState() {
        expect(self.stateA == MyState.aaa) == true
        expect(self.stateA == MyState.bbb) == false
    }

    func testEquatableStateNotEqualsConfig() {
        expect(MyState.aaa != self.stateA) == false
        expect(MyState.bbb != self.stateA) == true
    }

    func testEquatableConfigNotEqualsState() {
        expect(self.stateA != MyState.aaa) == false
        expect(self.stateA != MyState.bbb) == true
    }

    // MARK: - Pre-flight

    func testPreflightAllowsTransition() async {
        let result = await stateA.preflightTransition(toState: stateB, inMachine: MockMachine())
        expect(result) == .allow
    }

    func testPreflightSameStateFails() async {
        let result = await stateA.preflightTransition(toState: stateA, inMachine: MockMachine())
        expect(result) == .fail(error: .alreadyInState)
    }

    func testPreflightFinalStateExitFails() async {
        let result = await final.preflightTransition(toState: stateB, inMachine: MockMachine())
        expect(result) == .fail(error: .illegalTransition)
    }

    func testPreflightBarrierAllows() async {
        let barrierState = StateConfig<MyState>(.bbb, transitionBarrier: { _ in
            .allow
        })
        let result = await stateA.preflightTransition(toState: barrierState, inMachine: MockMachine())
        expect(result) == .allow
    }

    func testPreflightBarrierFails() async {
        let barrierState = StateConfig<MyState>(.bbb, transitionBarrier: { _ in
            .fail
        })
        let result = await stateA.preflightTransition(toState: barrierState, inMachine: MockMachine())
        expect(result) == .fail(error: .transitionDenied)
    }

    func testPreflightBarrierRedirects() async {
        let barrierState = StateConfig<MyState>(.bbb, transitionBarrier: { _ in
            .redirect(to: .ccc)
        })
        let result = await stateA.preflightTransition(toState: barrierState, inMachine: MockMachine())
        expect(result) == .redirect(to: .ccc)
    }

    func testPreflightAllowTransitionFails() async {
        let result = await stateA.preflightTransition(toState: stateC, inMachine: MockMachine())
        expect(result) == .fail(error: .illegalTransition)
    }

    func testPreflightAllowsGlobal() async {
        let result = await stateA.preflightTransition(toState: global, inMachine: MockMachine())
        expect(result) == .allow
    }
}
