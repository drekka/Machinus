//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

class StateConfigTests: XCTestCase {

    private var stateA: StateConfig<TestState> = StateConfig(.aaa, canTransitionTo: .bbb)
    private var stateAA: StateConfig<TestState> = StateConfig(.aaa)
    private var stateB: StateConfig<TestState> = StateConfig(.bbb)
    private var stateC: StateConfig<TestState> = StateConfig(.ccc)
    private var global: StateConfig<TestState> = StateConfig.global(.global, canTransitionTo: .aaa)
    private var final: StateConfig<TestState> = StateConfig.final(.final)

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

    // MARK: - Pre-flight

    func testPreflightAllowsTransition() throws {
        let result = try stateA.preflightTransition(toState: stateB, logger: testLog)
        expect(result) == .allow
    }

    func testPreflightSameStateFails() {
        stateA.expectPreflight(to: stateA, toFailWith: .alreadyInState)
    }

    func testPreflightFinalStateExitFails() {
        final.expectPreflight(to: stateB, toFailWith: .illegalTransition)
    }

    func testPreflightBarrierAllows() throws {
        let barrierState = StateConfig<TestState>(.bbb, transitionBarrier: { _ in
            .allow
        })
        let result = try stateA.preflightTransition(toState: barrierState, logger: testLog)
        expect(result) == .allow
    }

    func testPreflightBarrierAllowsThenAllowTransitionFails() {
        let barrierState = StateConfig<TestState>(.ccc, transitionBarrier: { _ in
            .allow
        })
        stateA.expectPreflight(to: barrierState, toFailWith: .illegalTransition)
    }

    func testPreflightBarrierFails() {
        let barrierState = StateConfig<TestState>(.bbb, transitionBarrier: { _ in
            .fail
        })
        stateA.expectPreflight(to: barrierState, toFailWith: .transitionDenied)
    }

    func testPreflightBarrierRedirects() throws {
        let barrierState = StateConfig<TestState>(.bbb, transitionBarrier: { _ in
            .redirect(to: .ccc)
        })
        let result = try stateA.preflightTransition(toState: barrierState, logger: testLog)
        expect(result) == .redirect(to: .ccc)
    }

    func testPreflightAllowTransitionFails() {
        stateA.expectPreflight(to: stateC, toFailWith: .illegalTransition)
    }

    func testPreflightAllowsGlobal() throws {
        let result = try stateA.preflightTransition(toState: global, logger: testLog)
        expect(result) == .allow
    }
}

extension StateConfig where S == TestState {

    func expectPreflight(file _: StaticString = #file, line _: UInt = #line, to nextState: StateConfig<S>, toFailWith expectedError: StateMachineError<S>) {
        do {
            _ = try preflightTransition(toState: nextState, logger: testLog)
        } catch let error as StateMachineError<S> {
            expect(error).to(equal(expectedError), description: "Incorrect error returned")
        } catch {
            fail("Unexpected error: \(error)")
        }
    }
}
