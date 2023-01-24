//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

class StateConfigTests: XCTestCase {

    private var stateA: StateConfig<TestState> = StateConfig(.aaa, allowedTransitions: .bbb, .ccc)
    private var stateAA: StateConfig<TestState> = StateConfig(.aaa)
    private var stateB: StateConfig<TestState> = StateConfig(.bbb)
    private var stateC: StateConfig<TestState> = StateConfig(.ccc)
    private var global: StateConfig<TestState> = StateConfig.global(.global, allowedTransitions: .aaa)
    private var final: StateConfig<TestState> = StateConfig.final(.final)

    // MARK: - Custom debug string convertable

    func testCustomStringConvertable() {
        expect(self.stateA.description) == ".aaa"
        expect(self.stateB.description) == ".bbb"
    }

    // MARK: - Equatable

    func testEquatableConfigEqualsConfig() {
        expect(self.stateA == self.stateAA) == true
        expect(self.stateA == self.stateB) == false
    }

    // MARK: - Factories

    // MARK: - Pre-flight

    func testPreflightAllowsTransition() throws {
        expect(self.stateA.preflightTransition(toState: self.stateB, logger: testLog)) == .allow
    }

    func testPreflightSameStateFails() {
        expect(self.stateA.preflightTransition(toState: self.stateA, logger: testLog)) == .fail(.alreadyInState)
    }

    func testPreflightFinalStateTransitionFails() {
        expect(self.final.preflightTransition(toState: self.stateA, logger: testLog)) == .fail(.illegalTransition)
    }

    func testPreflightCustomExitBarrierAllows() throws {
        let exitBarrierState = StateConfig<TestState>(.aaa, exitBarrier: { _ in .allow })
        expect(exitBarrierState.preflightTransition(toState: self.stateB, logger: testLog)) == .allow
    }

    func testPreflightCustomExitBarrierDisallows() throws {
        let exitBarrierState = StateConfig<TestState>(.aaa, exitBarrier: { _ in .disallow })
        expect(exitBarrierState.preflightTransition(toState: self.stateB, logger: testLog)) == .fail(.illegalTransition)
    }

    func testPreflightCustomExitBarrierDisallowsOverriddenByGlobal() throws {
        let exitBarrierState = StateConfig<TestState>(.aaa, exitBarrier: { _ in .disallow })
        expect(exitBarrierState.preflightTransition(toState: self.global, logger: testLog)) == .allow
    }

    func testPreflightCustomExitBarrierRedirects() throws {
        let exitBarrierState = StateConfig<TestState>(.aaa, exitBarrier: { _ in .redirect(to: .bbb) })
        expect(exitBarrierState.preflightTransition(toState: self.stateB, logger: testLog)) == .redirect(to: .bbb)
    }

    func testPreflightCustomExitBarrierFails() throws {
        let exitBarrierState = StateConfig<TestState>(.aaa, exitBarrier: { _ in .fail(.suspended) })
        expect(exitBarrierState.preflightTransition(toState: self.stateB, logger: testLog)) == .fail(.suspended)
    }

    func testPreflightToStateEntryBarrierAllows() throws {
        let currentState = StateConfig<TestState>(.aaa, allowedTransitions: .bbb)
        let entryBarrierState = StateConfig<TestState>(.bbb, entryBarrier: { _ in .allow })
        expect(currentState.preflightTransition(toState: entryBarrierState, logger: testLog)) == .allow
    }

    func testPreflightToStateEntryBarrierDisallows() throws {
        let currentState = StateConfig<TestState>(.aaa, allowedTransitions: .bbb)
        let entryBarrierState = StateConfig<TestState>(.bbb, entryBarrier: { _ in .disallow })
        expect(currentState.preflightTransition(toState: entryBarrierState, logger: testLog)) == .fail(.transitionDenied)
    }

    func testPreflightToStateEntryBarrierFails() throws {
        let currentState = StateConfig<TestState>(.aaa, allowedTransitions: .bbb)
        let entryBarrierState = StateConfig<TestState>(.bbb, entryBarrier: { _ in .fail(.suspended) })
        expect(currentState.preflightTransition(toState: entryBarrierState, logger: testLog)) == .fail(.suspended)
    }

    func testPreflightToStateEntryBarrierRedirects() throws {
        let currentState = StateConfig<TestState>(.aaa, allowedTransitions: .bbb, .ccc)
        let entryBarrierState = StateConfig<TestState>(.bbb, entryBarrier: { _ in .redirect(to: .ccc) })
        expect(currentState.preflightTransition(toState: entryBarrierState, logger: testLog)) == .redirect(to: .ccc)
    }
}
