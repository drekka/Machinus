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

    override func setUp() {
        super.setUp()
        log = []
    }

    // MARK: - Lifecycle

    func testInitWithLessThan3StatesGeneratesFatal() async throws {
        do {
            _ = try await StateMachine {
                StateConfig<TestState>(.aaa)
                StateConfig<TestState>(.bbb)
            }
        } catch StateMachineError<TestState>.configurationError(let message) {
            expect(message) == "Insufficient state. There must be at least 3 states."
        }
    }

    func testInitWithDuplicateStateIdentifiersGeneratesFatal() async throws {
        do {
            _ = try await StateMachine {
                StateConfig<TestState>(.aaa)
                StateConfig<TestState>(.bbb)
                StateConfig<TestState>(.aaa)
            }
        } catch StateMachineError<TestState>.configurationError(let message) {
            expect(message) == "Duplicate states detected for identifier .aaa."
        }
    }

    func testReset() async throws {

        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa,
                                   didEnter: { _, _, _ in self.log.append("aaaEnter") },
                                   canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb,
                                   didEnter: { _, _, _ in self.log.append("bbbEnter") },
                                   didExit: { _, _, _ in self.log.append("bbbExit") })
            StateConfig<TestState>(.ccc)
        }

        await machine.testTransition(to: .bbb)
        await machine.testReset(to: .aaa)

        expect(self.log) == ["bbbEnter", "aaaEnter"]
    }

    // MARK: - Transition to

    func testTransitionTo() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb)
    }

    func testTransitionClosureCalled() async throws {

        let machine = try await StateMachine { _, from, to in
            self.log.append("Did transition \(from) -> \(to)")
        }
        withStates: {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }

        await machine.testTransition(to: .bbb)

        expect(self.log) == ["Did transition aaa -> bbb"]
    }

    func testTransitionToUnregisteredStateFails() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .final, failsWith: .unknownState(.final))
    }

    func testTransitionClosureSequencing() async throws {

        let machine = try await StateMachine<TestState> { _, from, to in
            self.log.append("Did transition \(from) -> \(to)")
        }
        withStates: {
            StateConfig<TestState>(.aaa,
                                   didEnter: { _, _, _ in self.log.append("aaaEnter") },
                                   didExit: { _, _, _ in self.log.append("aaaExit") }, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb,
                                   didEnter: { _, _, _ in self.log.append("bbbEnter") },
                                   didExit: { _, _, _ in self.log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<TestState>(.ccc,
                                   didEnter: { _, _, _ in self.log.append("cccEnter") },
                                   didExit: { _, _, _ in self.log.append("cccExit") })
        }

        await machine.testTransition(to: .bbb)
        expect(self.log) == ["aaaExit", "bbbEnter", "Did transition aaa -> bbb"]

        await machine.testTransition(to: .ccc)
        expect(self.self.log) == ["aaaExit", "bbbEnter", "Did transition aaa -> bbb", "bbbExit", "cccEnter", "Did transition bbb -> ccc"]
    }

    func testTransitionClosureSequencingWhenNestedStateChange() async throws {

        let exp = expectation(description: "Nested transition")
        let machine = try await StateMachine { _, from, to in
            self.log.append("Did transition \(from) -> \(to)")
        }
        withStates: {
            StateConfig<TestState>(.aaa,
                                   didEnter: { _, _, _ in self.log.append("aaaEnter") },
                                   didExit: { _, _, _ in self.log.append("aaaExit") },
                                   canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb,
                                   didEnter: { machine, _, _ in
                                       self.log.append("bbbEnter")
                await machine.transition(to: .ccc) { _, _ in
                    exp.fulfill()
                }
                                   },
                                   didExit: { _, _, _ in self.log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<TestState>(.ccc,
                                   didEnter: { _, _, _ in self.log.append("cccEnter") },
                                   didExit: { _, _, _ in self.log.append("cccExit") })
        }

        await machine.testTransition(to: .bbb)
        wait(for: [exp], timeout: 5.0)
        expect(self.log) == ["aaaExit", "bbbEnter", "Did transition aaa -> bbb", "bbbExit", "cccEnter", "Did transition bbb -> ccc"]
    }

    // MARK: - Preflight failures

    func testTransitionToSameStateGeneratesErrorAndDoesntCallClosures() async throws {

        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa,
                                   didEnter: { _, _, _ in self.log.append("aaaEnter") },
                                   didExit: { _, _, _ in self.log.append("aaaExit") }, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb,
                                   didEnter: { _, _, _ in self.log.append("bbbEnter") },
                                   didExit: { _, _, _ in self.log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<TestState>(.ccc)
        }

        await machine.testTransition(to: .aaa, failsWith: .alreadyInState)
        expect(self.log) == []
    }

    func testTransitionToStateNotInAllowedListGeneratesError() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .ccc, failsWith: .illegalTransition)
    }

    func testTransitionBarrierAllowsTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb, transitionBarrier: { _ in .allow })
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb)
    }

    func testTransitionBarrierDeniesTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb, transitionBarrier: { _ in .fail })
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, failsWith: .transitionDenied)
    }

    func testTransitionBarrierRedirectsToAnotherState() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa, canTransitionTo: .bbb, .ccc)
            StateConfig<TestState>(.bbb, transitionBarrier: { _ in .redirect(to: .ccc) })
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, redirectsTo: .ccc)
    }

    func testTransitionFromFinalGeneratesError() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>.final(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, failsWith: .illegalTransition)
    }

    func testTransitionFromFinalGlobalGeneratesError() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>.finalGlobal(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testTransition(to: .bbb, failsWith: .illegalTransition)
    }

    // MARK: - Dynamic transitions

    func testDynamicTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa, dynamicTransition: { _ in .bbb }, canTransitionTo: .bbb)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testDynamicTransition(to: .bbb)
    }

    func testDynamicTransitionNotDefinedFailure() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>(.ccc)
        }
        await machine.testDynamicTransition(failsWith: .noDynamicClosure(.aaa))
    }

    // MARK: - Global states

    func testTransitionToGlobalAlwaysWorks() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>.global(.global)
        }
        await machine.testTransition(to: .global)
    }

    func testTransitionToFinalGlobal() async throws {
        let machine = try await StateMachine {
            StateConfig<TestState>(.aaa)
            StateConfig<TestState>(.bbb)
            StateConfig<TestState>.finalGlobal(.global)
        }
        await machine.testTransition(to: .global)
    }
}
