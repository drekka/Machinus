//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

class StateMachineTests: XCTestCase {

    // MARK: - Lifecycle

    func testName() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        func hex(_ length: Int) -> String { "[0-9A-Za-z]{\(length)}" }
        await expect({ await machine.name }).to(match("\(hex(8))-\(hex(4))-\(hex(4))-\(hex(4))-\(hex(12))<MyState>"))
    }

    func testInitWithLessThan3StatesGeneratesFatal() async throws {
        do {
            _ = try await StateMachine {
                StateConfig<MyState>(.aaa)
                StateConfig<MyState>(.bbb)
            }
        } catch StateMachineError.configurationError(let message) {
            expect(message) == "Insufficient state. There must be at least 3 states."
        }
    }

    func testInitWithDuplicateStateIdentifiersGeneratesFatal() async throws {
        do {
            _ = try await StateMachine {
                StateConfig<MyState>(.aaa)
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>(.aaa)
            }
        } catch StateMachineError.configurationError(let message) {
            expect(message) == "Duplicate states detected for identifier .aaa."
        }
    }

    func testReset() async throws {

        var aaaEnter = false

        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, didEnter: { _, _ in aaaEnter = true }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        await expect(machine.state).toEventually(equal(.aaa))

        await machine.transition(to: .bbb)
        await expect(machine.state).toEventually(equal(.bbb))

        await machine.reset()

        await expect(machine.state).toEventually(equal(.aaa))
        expect(aaaEnter) == true
    }

    // MARK: - Transitions

    func testTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        await machine.transition(to: .bbb)
        await expect(machine.state).toEventually(equal(.bbb))
    }

    func testTransitionClosureCalled() async throws {
        var callback: (StateMachine<MyState>, MyState)?
        let machine = try await StateMachine {
            callback = ($0, $1)
        }
        withStates: {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        await machine.transition(to: .bbb)
        await expect(callback?.0).toEventuallyNot(beNil())
        expect(callback?.0.state) == .bbb
        expect(callback?.1) == .aaa
    }

    func testTransitionToUnregisteredStateFails() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        var result: Result<MyState, StateMachineError>?
        await machine.transition(to: .final) {
            result = $0
        }
        await expect(result).toEventually(equal(.failure(.unknownState(MyState.final))))
    }

    func testTransitionClosuresInCorrectOrder() async throws {

        var log: [String] = []
        let machine = try await StateMachine<MyState> { machine, old in
            log.append("\(old) -> \(machine.state)")
        }
        withStates: {
            StateConfig<MyState>(.aaa, didEnter: { _, _ in log.append("aaaEnter") }, didExit: { _, _ in log.append("aaaExit") }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, didEnter: { _, _ in log.append("bbbEnter") }, didExit: { _, _ in log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc, didEnter: { _, _ in log.append("cccEnter") }, didExit: { _, _ in log.append("cccExit") })
        }

        await machine.transition(to: .bbb)
        await expect(machine.state).toEventually(equal(.bbb))
        expect(log) == ["aaaExit", "bbbEnter", "aaa -> bbb"]

        await machine.transition(to: .ccc)
        await expect(machine.state).toEventually(equal(.ccc))
        expect(log) == ["aaaExit", "bbbEnter", "aaa -> bbb", "bbbExit", "cccEnter", "bbb -> ccc"]
    }

    func testTransitionClosuresInCorrectOrderWhenNestedStateChange() async throws {

        var log: [String] = []
        let machine = try await StateMachine<MyState> { machine, old in
            log.append("\(old) -> \(machine.state)")
        }
        withStates: {
            StateConfig<MyState>(.aaa,
                                 didEnter: { _, _ in log.append("aaaEnter") },
                                 didExit: { _, _ in log.append("aaaExit") },
                                 canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb,
                                 didEnter: { machine, _ in
                                     log.append("bbbEnter")
                                     await machine.transition(to: .ccc)
                                 },
                                 didExit: { _, _ in log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc,
                                 didEnter: { _, _ in log.append("cccEnter") },
                                 didExit: { _, _ in log.append("cccExit") })
        }

        await machine.transition(to: .bbb)
        await expect(machine.state).toEventually(equal(.ccc))
        expect(log) == ["aaaExit", "bbbEnter", "aaa -> bbb", "bbbExit", "cccEnter", "bbb -> ccc"]
    }

    func testTransitionToSameStateGeneratesErrorAndDoesntCallClosures() async throws {

        var log: [String] = []
        let machine = try await StateMachine<MyState> {
            StateConfig<MyState>(.aaa, didEnter: { _, _ in log.append("aaaEnter") }, didExit: { _, _ in log.append("aaaExit") }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, didEnter: { _, _ in log.append("bbbEnter") }, didExit: { _, _ in log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .aaa, toFailWith: .alreadyInState)
        expect(log) == []
    }

    func testTransitionToStateNotInAllowedListGeneratesError() async throws {

        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .ccc, toFailWith: .illegalTransition)
    }

    func testTransitionBarrierAllowsTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, transitionBarrier: { .allow })
            StateConfig<MyState>(.ccc)
        }

        await machine.transition(to: .bbb)
        await expect(machine.state).toEventually(equal(.bbb))
    }

    func testTransitionBarrierDeniesTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, transitionBarrier: { .fail })
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .bbb, toFailWith: .transitionDenied)
    }

    func testTransitionBarrierRedirectsToAnotherState() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb, .ccc)
            StateConfig<MyState>(.bbb, transitionBarrier: { .redirect(to: .ccc) })
            StateConfig<MyState>(.ccc)
        }

        await machine.transition(to: .bbb)
        await expect(machine.state).toEventually(equal(.ccc))
    }

    func testTransitionFromFinalGeneratesError() async throws {

        let machine = try await StateMachine {
            StateConfig<MyState>.final(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .bbb, toFailWith: .illegalTransition)
    }

    func testTransitionFromFinalGlobalGeneratesError() async throws {

        let machine = try await StateMachine {
            StateConfig<MyState>.finalGlobal(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .bbb, toFailWith: .illegalTransition)
    }

    // MARK: - Dynamic transitions

    func testDynamicTransition() async throws {

        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, dynamicTransition: { .bbb }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        await machine.transition()
        await expect(machine.state).toEventually(equal(.bbb))
    }

    func testDynamicTransitionNotDefinedFailure() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        var result: Result<MyState, StateMachineError>?
        await machine.transition { result = $0 }
        await expect(result).toEventually(equal(.failure(StateMachineError.noDynamicClosure(MyState.aaa))))
    }

    // MARK: - Global states

    func testTransitionToGlobalAlwaysWorks() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>.global(.global)
        }

        await machine.transition(to: .global)
    }

    func testTransitionToFinalGlobal() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>.finalGlobal(.global)
        }

        await machine.transition(to: .global)
    }

    // MARK: - Internal

    private func expectTransition(_ machine: StateMachine<MyState>, to nextState: MyState,
                                  toFailWith expectedError: StateMachineError,
                                  file: StaticString = #file, line: UInt = #line) async {
        var result: Result<MyState, StateMachineError>?
        await machine.transition(to: nextState) { result = $0 }

        var error: StateMachineError?
        await expect(file: file, line: line, result).toEventually(beFailure { error = $0 })
        expect(file: file, line: line, error).to(matchError(expectedError))
    }
}
