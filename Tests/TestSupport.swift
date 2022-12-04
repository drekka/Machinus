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

actor MockMachine: Machine {

    let name = "Mock Machine"
    let stateConfigs: [MyState: StateConfig<MyState>]
    let initialState: StateConfig<MyState>
    let currentState: CurrentValueSubject<StateConfig<MyState>, StateMachineError>

    nonisolated var currentStateConfig: StateConfig<MyState> {
        currentState.value
    }
    nonisolated var state: MyState {
        currentStateConfig.identifier
    }

    func queue(transition _: @escaping (any Machine<MyState>) async throws -> StateConfig<MyState>, completion _: ((Result<MyState, StateMachineError>) -> Void)?) async {}

    var transitionToStateResult: StateConfig<MyState>?
    func transitionToState(_: MyState) async throws -> StateConfig<MyState> {
        transitionToStateResult!
    }

    var transitionResult: StateConfig<MyState>?
    func transition(toState _: StateConfig<MyState>, didExit _: DidExit<MyState>?, didEnter _: DidEnter<MyState>?) async -> StateConfig<MyState> {
        transitionResult!
    }

    init(states: [StateConfig<MyState>]) {
        stateConfigs = Dictionary(uniqueKeysWithValues: states.map { ($0.identifier, $0) })
        initialState = states[0]
        currentState = CurrentValueSubject(states[0])
    }
}
