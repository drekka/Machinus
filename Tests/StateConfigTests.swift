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

    // MARK: - Hashable

    func testHashValue() {
        expect(self.stateA.hashValue) == TestState.aaa.hashValue
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
        expect(TestState.aaa == self.stateA) == true
        expect(TestState.bbb == self.stateA) == false
    }

    func testEquatableConfigEqualsState() {
        expect(self.stateA == TestState.aaa) == true
        expect(self.stateA == TestState.bbb) == false
    }

    func testEquatableStateNotEqualsConfig() {
        expect(TestState.aaa != self.stateA) == false
        expect(TestState.bbb != self.stateA) == true
    }

    func testEquatableConfigNotEqualsState() {
        expect(self.stateA != TestState.aaa) == false
        expect(self.stateA != TestState.bbb) == true
    }

    // MARK: - Pre-flight

    func testPreflightAllowsTransition() async throws {
        let result = try await stateA.preflightTransition(toState: stateB, inMachine: MockMachine())
        expect(result) == .allow
    }

    func testPreflightSameStateFails() async {
        await stateA.expectPreflight(to: stateA, toFailWith: .alreadyInState)
    }

    func testPreflightFinalStateExitFails() async {
        await final.expectPreflight(to: stateB, toFailWith: .illegalTransition)
    }

    func testPreflightBarrierAllows() async throws {
        let barrierState = StateConfig<TestState>(.bbb, transitionBarrier: { _ in
            .allow
        })
        let result = try await stateA.preflightTransition(toState: barrierState, inMachine: MockMachine())
        expect(result) == .allow
    }

    func testPreflightBarrierAllowsThenAllowTransitionFails() async {
        let barrierState = StateConfig<TestState>(.ccc, transitionBarrier: { _ in
            .allow
        })
        await stateA.expectPreflight(to: barrierState, toFailWith: .illegalTransition)
    }

    func testPreflightBarrierFails() async {
        let barrierState = StateConfig<TestState>(.bbb, transitionBarrier: { _ in
            .fail
        })
        await stateA.expectPreflight(to: barrierState, toFailWith: .transitionDenied)
    }

    func testPreflightBarrierRedirects() async throws {
        let barrierState = StateConfig<TestState>(.bbb, transitionBarrier: { _ in
            .redirect(to: .ccc)
        })
        let result = try await stateA.preflightTransition(toState: barrierState, inMachine: MockMachine())
        expect(result) == .redirect(to: .ccc)
    }

    func testPreflightAllowTransitionFails() async {
        await stateA.expectPreflight(to: stateC, toFailWith: .illegalTransition)
    }

    func testPreflightAllowsGlobal() async throws {
        let result = try await stateA.preflightTransition(toState: global, inMachine: MockMachine())
        expect(result) == .allow
    }
}

extension StateConfig where S == TestState {

    func expectPreflight(file _: StaticString = #file, line _: UInt = #line, to nextState: StateConfig<S>, toFailWith expectedError: StateMachineError<S>) async {
        do {
            _ = try await preflightTransition(toState: nextState, inMachine: MockMachine())
        } catch let error as StateMachineError<S> {
            expect(error).to(equal(expectedError), description: "Incorrect error returned")
        } catch {
            fail("Unexpected error: \(error)")
        }
    }
}
