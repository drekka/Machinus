//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

class StateMachineTests: XCTestCase {

    private var log: Log!

    override func setUp() {
        super.setUp()
        log = Log()
    }

    // MARK: - Lifecycle

    func testName() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        func hex(_ length: Int) -> String { "[0-9A-Za-z]{\(length)}" }
        expect(machine.name).to(match("\(hex(8))-\(hex(4))-\(hex(4))-\(hex(4))-\(hex(12))<MyState>"))
    }

    func testInitWithLessThan3StatesGeneratesFatal() async throws {
        do {
            _ = try await StateMachine {
                StateConfig<MyState>(.aaa)
                StateConfig<MyState>(.bbb)
            }
        } catch StateMachineError<MyState>.configurationError(let message) {
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
        } catch StateMachineError<MyState>.configurationError(let message) {
            expect(message) == "Duplicate states detected for identifier .aaa."
        }
    }

    func testReset() async throws {

        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, didEnter: { _, _ in await self.log.append("aaaEnter") }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, didEnter: { _, _ in await self.log.append("bbbEnter") }, didExit: { _, _ in await self.log.append("bbbExit") })
            StateConfig<MyState>(.ccc)
        }
        expectMachine(machine, toEventuallyHaveState: .aaa)

        try await machine.transition(to: .bbb)
        expectMachine(machine, toEventuallyHaveState: .bbb)

        try await machine.reset()

        expectMachine(machine, toEventuallyHaveState: .aaa)
        await expect({ await self.log.entries }) == ["bbbEnter", "aaaEnter"]
    }

    // MARK: - Transitions

    func testTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        try await machine.transition(to: .bbb)
        expectMachine(machine, toEventuallyHaveState: .bbb)
    }

    @available(iOS 16.0.0, *)
    func testTransitionClosureCalled() async throws {

        var didTransitionMachine: (any Machine<MyState>)? // Generic'd protocols are only useable like this in iOS16
        var didTransitionPreviousState: MyState?
        let machine = try await StateMachine {
            didTransitionMachine = $0
            didTransitionPreviousState = $1
        }
        withStates: {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        try await machine.transition(to: .bbb)

        await expect(didTransitionPreviousState).toEventuallyNot(beNil())
        await expect({ await didTransitionMachine?.state }) == .bbb
        expect(didTransitionPreviousState) == .aaa
        expect(didTransitionMachine) === machine
    }

    func testTransitionToUnregisteredStateFails() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        do {
            try await machine.transition(to: .final)
        } catch StateMachineError<MyState>.unknownState(let state) {
            expect(state) == MyState.final
        }
    }

    func testTransitionClosuresInCorrectOrder() async throws {

        let machine = try await StateMachine<MyState> { machine, old in
            await self.log.append("\(old) -> \(machine.state)")
        }
        withStates: {
            StateConfig<MyState>(.aaa,
                                 didEnter: { _, _ in await self.log.append("aaaEnter") },
                                 didExit: { _, _ in await self.log.append("aaaExit") }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb,
                                 didEnter: { _, _ in await self.log.append("bbbEnter") },
                                 didExit: { _, _ in await self.log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc,
                                 didEnter: { _, _ in await self.log.append("cccEnter") },
                                 didExit: { _, _ in await self.log.append("cccExit") })
        }

        try await machine.transition(to: .bbb)
        expectMachine(machine, toEventuallyHaveState: .bbb)
        await expect({ await self.log.entries }) == ["aaaExit", "bbbEnter", "aaa -> bbb"]

        try await machine.transition(to: .ccc)
        expectMachine(machine, toEventuallyHaveState: .ccc)
        await expect({ await self.log.entries }) == ["aaaExit", "bbbEnter", "aaa -> bbb", "bbbExit", "cccEnter", "bbb -> ccc"]
    }

    func testTransitionClosuresInCorrectOrderWhenNestedStateChange() async throws {

        let machine = try await StateMachine<MyState> { machine, old in
            await self.log.append("Machine \(old) -> \(machine.state)")
        }
        withStates: {
            StateConfig<MyState>(.aaa,
                                 didEnter: { _, _ in await self.log.append("aaaEnter") },
                                 didExit: { _, _ in await self.log.append("aaaExit") },
                                 canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb,
                                 didEnter: { machine, _ in
                                     await self.log.append("bbbEnter")
                                     try! await machine.transition(to: .ccc)
                                 },
                                 didExit: { _, _ in await self.log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc,
                                 didEnter: { _, _ in await self.log.append("cccEnter") },
                                 didExit: { _, _ in await self.log.append("cccExit") })
        }

        try await machine.transition(to: .bbb)
        expectMachine(machine, toEventuallyHaveState: .ccc)
        await expect({ await self.log.entries }) == ["aaaExit", "bbbEnter", "aaa -> bbb", "bbbExit", "cccEnter", "bbb -> ccc"]
    }

    // MARK: - Preflight failures

    func testTransitionToSameStateGeneratesErrorAndDoesntCallClosures() async throws {

        let machine = try await StateMachine<MyState> {
            StateConfig<MyState>(.aaa,
                                 didEnter: { _, _ in await self.log.append("aaaEnter") },
                                 didExit: { _, _ in await self.log.append("aaaExit") }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb,
                                 didEnter: { _, _ in await self.log.append("bbbEnter") },
                                 didExit: { _, _ in await self.log.append("bbbExit") }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .aaa, toFailWith: .alreadyInState)
        await expect({ await self.log.entries }) == []
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
            StateConfig<MyState>(.bbb, transitionBarrier: { _ in .allow })
            StateConfig<MyState>(.ccc)
        }

        try await machine.transition(to: .bbb)
        expectMachine(machine, toEventuallyHaveState: .bbb)
    }

    func testTransitionBarrierDeniesTransition() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, transitionBarrier: { _ in .fail })
            StateConfig<MyState>(.ccc)
        }

        await expectTransition(machine, to: .bbb, toFailWith: .transitionDenied)
    }

    func testTransitionBarrierRedirectsToAnotherState() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb, .ccc)
            StateConfig<MyState>(.bbb, transitionBarrier: { _ in .redirect(to: .ccc) })
            StateConfig<MyState>(.ccc)
        }

        try await machine.transition(to: .bbb)
        expectMachine(machine, toEventuallyHaveState: .ccc)
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
            StateConfig<MyState>(.aaa, dynamicTransition: { _ in .bbb }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        try await machine.transition()
        expectMachine(machine, toEventuallyHaveState: .bbb)
    }

    func testDynamicTransitionNotDefinedFailure() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        do {
            try await machine.transition()
        } catch StateMachineError<MyState>.noDynamicClosure(let state) {
            expect(state) == .aaa
        }
    }

    // MARK: - Global states

    func testTransitionToGlobalAlwaysWorks() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>.global(.global)
        }

        try await machine.transition(to: .global)
    }

    func testTransitionToFinalGlobal() async throws {
        let machine = try await StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>.finalGlobal(.global)
        }

        try await machine.transition(to: .global)
    }

    // MARK: - Internal

    private func expectTransition(_ machine: StateMachine<MyState>, to nextState: MyState,
                                  toFailWith expectedError: StateMachineError<MyState>,
                                  file: StaticString = #file, line: UInt = #line) async {
        do {
            try await machine.transition(to: nextState)
            fail("Error not thrown", file:file, line:line)
        }
        catch let error as StateMachineError<MyState> {
            expect(error) == expectedError
        }
        catch {
            fail("Unexpected error \(error)", file:file, line:line)
        }
    }
}
