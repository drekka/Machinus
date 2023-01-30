//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import RegexBuilder
import XCTest

class StateMachineTests: XCTestCase {

    private var log: [String]!

    private var machine: StateMachine<TestState>!

    private lazy var loopedStates: [StateConfig<TestState>] = {
        [
            StateConfig<TestState>(.aaa,
                                   didEnter: { _ in self.log.append("aaaEnter") },
                                   allowedTransitions: .bbb, .ccc, .final,
                                   didExit: { _ in self.log.append("aaaExit") }),
            StateConfig<TestState>(.bbb,
                                   didEnter: { _ in self.log.append("bbbEnter") },
                                   allowedTransitions: .ccc,
                                   didExit: { _ in self.log.append("bbbExit") }),
            StateConfig<TestState>(.ccc,
                                   didEnter: { _ in self.log.append("cccEnter") },
                                   allowedTransitions: .aaa,
                                   didExit: { _ in self.log.append("cccExit") }),
            StateConfig<TestState>.global(.global,
                                          didEnter: { _ in self.log.append("globalEnter") },
                                          allowedTransitions: .aaa,
                                          didExit: { _ in self.log.append("globalExit") }),
            StateConfig<TestState>.final(.final,
                                         didEnter: { _ in self.log.append("finalEnter") }),
            StateConfig<TestState>.finalGlobal(.finalGlobal,
                                               didEnter: { _ in self.log.append("finalGlobalEnter") }),
        ]
    }()

    override func setUp() {
        super.setUp()
        log = []
        machine = StateMachine(name: "Test machine", withStates: loopedStates) { self.log.append("\($0) -> \($1)") }
    }

    // MARK: - Lifecycle

    func testInitializerWithBuilder() {
        _ = StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
    }

    func testInitializerWithVarArgList() {
        _ = StateMachine<TestState>(withStates: StateConfig(.aaa), StateConfig(.bbb), StateConfig(.ccc))
    }

    func testReset() async {
        await machine.testTransition(to: .bbb)
        await machine.testResets(to: .aaa)
        expect(self.log) == ["aaaExit", "bbbEnter", "aaa -> bbb"]
    }

    // MARK: - Transition to

    func testTransitionTo() async {
        let machine = StateMachine(withStates: loopedStates)
        await machine.testTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter"]
    }

    func testTransitionToGlobal() async {
        let machine = StateMachine(withStates: loopedStates)
        await machine.testTransition(to: .global)
        expect(self.log) == ["aaaExit", "globalEnter"]
    }

    func testTransitionToFinalGlobal() async {
        let machine = StateMachine(withStates: loopedStates)
        await machine.testTransition(to: .finalGlobal)
        expect(self.log) == ["aaaExit", "finalGlobalEnter"]
    }

    func testTransitionUsingDynamicClosure() async {
        machine[.aaa].dynamicTransition = { .bbb }
        await machine.testDynamicTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter", "aaa -> bbb"]
    }

    func testTransitionUsingDynamicClosureNoClosureError() async {
        await machine.testDynamicTransition(failsWith: .noDynamicClosure(.aaa))
    }

    // MARK: - Preflight failures

    func testPreflightSameStateError() async {
        await machine.testTransition(to: .aaa, failsWith: .alreadyInState)
    }

    func testPreflightFinalStateError() async {
        await machine.testTransition(to: .final)
        await machine.testTransition(to: .ccc, failsWith: .illegalTransition)
    }

    func testPreflightToUnknownStateError() async {
        await machine.testTransition(to: .unregistered, failsWith: .unknownState(.unregistered))
    }

    func testPreflightStateNotInAllowedListError() async {
        await machine.testTransition(to: .bbb)
        await machine.testTransition(to: .aaa, failsWith: .illegalTransition)
    }

    // MARK: - Exit barrier

    func testPreflightExitBarrierAllows() async {
        machine[.aaa].exitBarrier = { _ in .allow }
        await machine.testTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter", "aaa -> bbb"]
    }

    func testPreflightExitBarrierDeniesError() async {
        machine[.aaa].exitBarrier = { _ in .deny }
        await machine.testTransition(to: .bbb, failsWith: .illegalTransition)
    }

    func testPreflightExitBarrierDeniesButAllowsGlobal() async {
        machine[.aaa].exitBarrier = { _ in .deny }
        await machine.testTransition(to: .global)
        expect(self.log) == ["aaaExit", "globalEnter", "aaa -> global"]
    }

    func testPreflightExitBarrierRedirects() async {
        machine[.aaa].exitBarrier = { _ in .redirect(to: .ccc) }
        await machine.testTransition(to: .bbb, redirectsTo: .ccc)
        expect(self.log) == ["aaaExit", "cccEnter", "aaa -> ccc"]
    }

    func testPreflightExitBarrierRedirectsToUnregisteredStateError() async {
        machine[.aaa].exitBarrier = { _ in .redirect(to: .unregistered) }
        await machine.testTransition(to: .bbb, failsWith: .unknownState(.unregistered))
    }

    func testPreflightExitBarrierFails() async {
        machine[.aaa].exitBarrier = { _ in .fail(.suspended) }
        await machine.testTransition(to: .bbb, failsWith: .suspended)
    }

    // MARK: - Entry barrier

    func testPreflightEntryBarrierAllows() async {
        machine[.bbb].entryBarrier = { _ in .allow }
        await machine.testTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter", "aaa -> bbb"]
    }

    func testPreflightEntryBarrierDeniesError() async {
        machine[.bbb].entryBarrier = { _ in .deny }
        await machine.testTransition(to: .bbb, failsWith: .transitionDenied)
    }

    func testPreflightEntryBarrierRedirects() async {
        machine[.bbb].entryBarrier = { _ in .redirect(to: .ccc) }
        await machine.testTransition(to: .bbb, redirectsTo: .ccc)
        expect(self.log) == ["aaaExit", "cccEnter", "aaa -> ccc"]
    }

    func testPreflightEntryBarrierRedirectsToUnregisteredStateError() async {
        machine[.bbb].entryBarrier = { _ in .redirect(to: .unregistered) }
        await machine.testTransition(to: .bbb, failsWith: .unknownState(.unregistered))
    }

    func testPreflightEntryBarrierFails() async {
        machine[.bbb].entryBarrier = { _ in .fail(.suspended) }
        await machine.testTransition(to: .bbb, failsWith: .suspended)
    }
}
