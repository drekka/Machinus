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

    private lazy var loopedStates: [StateConfig<TestState>] = {
        [
            StateConfig<TestState>(.aaa,
                                   didEnter: { _, _ in self.log.append("aaaEnter") },
                                   didExit: { _, _ in self.log.append("aaaExit") },
                                   canTransitionTo: .bbb),
            StateConfig<TestState>(.bbb,
                                   didEnter: { _, _ in self.log.append("bbbEnter") },
                                   didExit: { _, _ in self.log.append("bbbExit") },
                                   canTransitionTo: .ccc),
            StateConfig<TestState>(.ccc,
                                   didEnter: { _, _ in self.log.append("cccEnter") },
                                   didExit: { _, _ in self.log.append("cccExit") },
                                   canTransitionTo: .aaa),
        ]
    }()

    override func setUp() {
        super.setUp()
        log = []
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

    func testInitializerWithArray() {
        _ = StateMachine<TestState>(withStates: [StateConfig(.aaa), StateConfig(.bbb), StateConfig(.ccc)])
    }

    func testReset() async {
        let machine = StateMachine(withStates: loopedStates)
        await machine.testTransition(to: .bbb)
        await machine.testResets(to: .aaa)
        expect(self.log) == ["aaaExit", "bbbEnter"]
    }

    // MARK: - Transition to

    func testTransitionTo() async {
        let machine = StateMachine(withStates: loopedStates)
        await machine.testTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter"]
    }

    func testTransitionToUnregisteredStateFails() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .final, failsWith: .unknownState(.final))
    }

    func testTransitionClosureSequencing() async {
        let machine = StateMachine(withStates: loopedStates) { self.log.append("\($0) -> \($1)") }

        await machine.testTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter", "aaa -> bbb"]

        await machine.testTransition(to: .ccc)
        expect(self.log) == ["aaaExit", "bbbEnter", "aaa -> bbb", "bbbExit", "cccEnter", "bbb -> ccc"]
    }

    // MARK: - Preflight failures

    func testTransitionToSameStateGeneratesErrorAndDoesntCallClosures() async {
        let machine = StateMachine(withStates: loopedStates)
        await machine.testTransition(to: .aaa, failsWith: .alreadyInState)
        expect(self.log) == []
    }

    func testTransitionToStateNotInAllowedListGeneratesError() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .ccc, failsWith: .illegalTransition)
    }

    func testTransitionBarrierAllowsTransition() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb, transitionBarrier: { _ in .allow })
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb)
    }

    func testTransitionBarrierDeniesTransition() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb, transitionBarrier: { _ in .fail })
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, failsWith: .transitionDenied)
    }

    func testTransitionBarrierRedirectsToAnotherState() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb, .ccc)
            StateConfig<TestState>(.bbb, transitionBarrier: { _ in .redirect(to: .ccc) })
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, redirectsTo: .ccc)
    }

    func testTransitionFromFinalGeneratesError() async {
        let machine = StateMachine {
            StateConfig<TestState>.final(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, failsWith: .illegalTransition)
    }

    func testTransitionFromFinalGlobalGeneratesError() async {
        let machine = StateMachine {
            StateConfig<TestState>.finalGlobal(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, failsWith: .illegalTransition)
    }

    // MARK: - Dynamic transitions

    func testDynamicTransition() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa, dynamicTransition: { .bbb }, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testDynamicTransition(to: .bbb)
    }

    func testDynamicTransitionNotDefinedFailure() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testDynamicTransition(failsWith: .noDynamicClosure(.aaa))
    }

    // MARK: - Global states

    func testTransitionToGlobalAlwaysWorks() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>.global(.global)
        }
        await machine.testTransition(to: .global)
    }

    func testTransitionToFinalGlobal() async {
        let machine = StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>.finalGlobal(.global)
        }
        await machine.testTransition(to: .global)
    }
}
