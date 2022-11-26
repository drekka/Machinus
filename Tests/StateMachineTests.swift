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


class StateMachineTests: XCTestCase {

    // MARK: - Lifecycle

    func testName() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        func hex(_ length: Int) -> String { "[0-9A-Za-z]{\(length)}" }
        expect(machine.name).to(match("\(hex(8))-\(hex(4))-\(hex(4))-\(hex(4))-\(hex(12))<MyState>"))
    }

    func testInitWithLessThan3StatesGeneratesFatal() {
        expect(_ = StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
        }).to(throwAssertion())
    }

    func testInitWithDuplicateStateIdentifiersGeneratesFatal() {
        expect(_ = StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.aaa)
        }).to(throwAssertion())
    }

    func testReset() {

        var aaaEnter = false

        let machine = StateMachine {
            StateConfig<MyState>(.aaa, didEnter: { _ in aaaEnter = true }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        expect(machine.state) == .aaa

        machine.transition(to: .bbb)
        expect(machine.state).toEventually(equal(.bbb))

        machine.reset()

        expect(machine.state).toEventually(equal(.aaa))
        expect(aaaEnter) == true
    }

    // MARK: - Transitions

    func testTransition() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }
        machine.transition(to: .bbb)
        expect(machine.state).toEventually(equal(.bbb))
    }

    func testTransitionClosureCalled() {
        var callback: (MyState, MyState)?
        let machine = StateMachine {
            callback = ($0, $1)
        }
        withStates: {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        machine.transition(to: .bbb)
        expect(callback?.0).toEventually(equal(.aaa))
        expect(callback?.1) == .bbb
    }

    func testTransitionToUnregisteredStateGeneratesFatal() {
//        let machine = StateMachine {
//            StateConfig<MyState>(.aaa)
//            StateConfig<MyState>(.bbb)
//            StateConfig<MyState>(.ccc)
//        }
//        expect(machine.transition(to: .final)).to(throwAssertion())
    }

    func testTransitionStateConfigEnterAndExitClosuresCalled() {

        var aaaEnter = false
        var aaaExit = false
        var bbbEnter = false
        var bbbExit = false
        var cccEnter = false
        var cccExit = false

        let machine = StateMachine {
            StateConfig<MyState>(.aaa, didEnter: { _ in aaaEnter = true }, didExit: { _ in aaaExit = true }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, didEnter: { _ in bbbEnter = true }, didExit: { _ in bbbExit = true }, canTransitionTo: .ccc)
            StateConfig<MyState>(.ccc, didEnter: { _ in cccEnter = true }, didExit: { _ in cccExit = true })
        }

        machine.transition(to: .bbb)
        expect(machine.state).toEventually(equal(.bbb))
        expect(aaaEnter) == false
        expect(aaaExit) == true
        expect(bbbEnter) == true
        expect(bbbExit) == false
        expect(cccEnter) == false
        expect(cccExit) == false

        aaaExit = false
        bbbEnter = false

        machine.transition(to: .ccc)
        expect(machine.state).toEventually(equal(.ccc))
        expect(aaaEnter) == false
        expect(aaaExit) == false
        expect(bbbEnter) == false
        expect(bbbExit) == true
        expect(cccEnter) == true
        expect(cccExit) == false
    }

    func testTransitionToSameStateGeneratesErrorAndDoesntCallClosures() {

        var aaaEnter = false
        var aaaExit = false
        var bbbEnter = false
        var bbbExit = false

        let machine = StateMachine {
            StateConfig<MyState>(.aaa, didEnter: { _ in aaaEnter = true }, didExit: { _ in aaaExit = true })
            StateConfig<MyState>(.bbb, didEnter: { _ in bbbEnter = true }, didExit: { _ in bbbExit = true })
            StateConfig<MyState>(.ccc)
        }

        expectTransition(machine, to: .aaa, toFailWith: .alreadyInState)

        expect(aaaEnter) == false
        expect(aaaExit) == false
        expect(bbbEnter) == false
        expect(bbbExit) == false
    }

    func testTransitionToStateNotInAllowedListGeneratesError() {

        let machine = StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        expectTransition(machine, to: .ccc, toFailWith: .illegalTransition)
    }

    func testTransitionBarrierAllowsTransition() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, transitionBarrier: { .allow })
            StateConfig<MyState>(.ccc)
        }

        machine.transition(to: .bbb)
        expect(machine.state).toEventually(equal(.bbb))
    }

    func testTransitionBarrierDeniesTransition() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb, transitionBarrier: { .fail })
            StateConfig<MyState>(.ccc)
        }

        expectTransition(machine, to: .bbb, toFailWith: .transitionDenied)
    }

    func testTransitionBarrierRedirectsToAnotherState() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa, canTransitionTo: .bbb, .ccc)
            StateConfig<MyState>(.bbb, transitionBarrier: { .redirect(to: .ccc) })
            StateConfig<MyState>(.ccc)
        }

        machine.transition(to: .bbb)
        expect(machine.state).toEventually(equal(.ccc))
    }

    func testTransitionFromFinalGeneratesError() {

        let machine = StateMachine {
            StateConfig<MyState>.final(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        expectTransition(machine, to: .bbb, toFailWith: .finalState)
    }

    func testTransitionFromFinalGlobalGeneratesError() {

        let machine = StateMachine {
            StateConfig<MyState>.finalGlobal(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        expectTransition(machine, to: .bbb, toFailWith: .finalState)
    }

    // MARK: - Dynamic transitions

    func testDynamicTransition() {

        let machine = StateMachine {
            StateConfig<MyState>(.aaa, dynamicTransition: { .bbb }, canTransitionTo: .bbb)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>(.ccc)
        }

        machine.transition()
        expect(machine.state).toEventually(equal(.bbb))
    }

    func testDynamicTransitionNotDefinedFailure() {
//        let machine = StateMachine {
//            StateConfig<MyState>(.aaa)
//            StateConfig<MyState>(.bbb)
//            StateConfig<MyState>(.ccc)
//        }
//        expect(machine.transition()).toEventually(throwAssertion())
    }

    // MARK: - Global states

    func testTransitionToGlobalAlwaysWorks() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>.global(.global)
        }

        machine.transition(to: .global)
    }

    func testTransitionToFinalGlobal() {
        let machine = StateMachine {
            StateConfig<MyState>(.aaa)
            StateConfig<MyState>(.bbb)
            StateConfig<MyState>.finalGlobal(.global)
        }

        machine.transition(to: .global)
    }

    // MARK: - Internal

    private func expectTransition(_ machine: StateMachine<MyState>, to nextState: MyState,
                                  toFailWith expectedError: StateMachineError,
                                  file: StaticString = #file, line: UInt = #line) {
        var result: Result<MyState, Error>?
        machine.transition(to: nextState) { result = $0 }

        var error: Error?
        expect(file: file, line: line, result).toEventually(beFailure { error = $0 })
        expect(file: file, line: line, error).to(matchError(expectedError))
    }
}
