//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
@testable import Machinus
import Nimble
import XCTest

enum MyState: StateIdentifier {
    case aaa
    case bbb
    case ccc
    case background
    case final
    case global
}

/// Used to log hooks and events in tests.
actor Log {
    var entries: [String] = []
    func append(_ value: String) {
        entries.append(value)
    }
}

extension StateMachineError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {

        case (.transitionDenied, .transitionDenied),
             (.alreadyInState, .alreadyInState),
             (.illegalTransition, .illegalTransition):
            return true

        case (.noDynamicClosure(let lhsState as MyState), .noDynamicClosure(let rhsState as MyState)),
             (.unknownState(let lhsState as MyState), .unknownState(let rhsState as MyState)):
            return lhsState == rhsState

        default:
            return false
        }
    }
}

extension StateConfig<MyState>.PreflightResponse<MyState>: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.allow, .allow):
            return true
        case (.fail(let lhsError), .fail(let rhsError)):
            return lhsError == rhsError
        case (.redirect(let lhsState), .redirect(let rhsState)):
            return lhsState == rhsState
        default:
            return false
        }
    }
}

extension XCTestCase {

    func expectMachine<S>(file _: StaticString = #file, line _: UInt = #line, _ machine: StateMachine<S>, toEventuallyHaveState desiredState: S) where S: StateIdentifier {

        let exp = expectation(description: "State wait")

        let c = machine.statePublisher.sink { _ in } receiveValue: { state in
            if state == desiredState {
                exp.fulfill()
            }
        }

        withExtendedLifetime(c) {
            wait(for: [exp], timeout: 5.0)
        }
    }
}

actor MockMachine: Machine {

    let name = "Mock Machine"
    var state: MyState

    init() {
        self.state = .aaa
    }

    func reset() async throws -> MyState {
        state
    }

    func transition() async throws -> MyState {
        state
    }

    func transition(to state: MyState) async throws -> MyState {
        state
    }
}

actor MockExecutor: TransitionExecutor {

    let name = "Mock Executor"
    let stateConfigs: [MyState: StateConfig<MyState>]
    let initialState: StateConfig<MyState>
    let currentState: CurrentValueSubject<StateConfig<MyState>, StateMachineError<MyState>>

    nonisolated var currentStateConfig: StateConfig<MyState> {
        currentState.value
    }

    nonisolated var state: MyState {
        currentStateConfig.identifier
    }

    var executeResult: StateConfig<MyState>?
    func execute(transition _: @escaping () async throws -> StateConfig<MyState>) async throws -> StateConfig<MyState> {
        executeResult!
    }

    var transitionResult: StateConfig<MyState>?
    func completeTransition(toState _: StateConfig<MyState>, didExit _: DidExit<MyState>?, didEnter _: DidEnter<MyState>?) async -> StateConfig<MyState> {
        transitionResult!
    }

    init(states: [StateConfig<MyState>]) {
        stateConfigs = Dictionary(uniqueKeysWithValues: states.map { ($0.identifier, $0) })
        initialState = states[0]
        currentState = CurrentValueSubject(states[0])
    }
}
