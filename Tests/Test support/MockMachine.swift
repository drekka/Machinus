//
//  Created by Derek Clarkson on 9/12/2022.
//

import Combine
import Foundation
@testable import Machinus
import os

actor MockMachine: Transitionable {
    let logger = Logger(subsystem: "au.com.derekclarkson.Machinus", category: "🤖 Testing")

    let stateConfigs: [TestState: StateConfig<TestState>]
    let initialState: StateConfig<TestState>

    let currentStateSubject: CurrentValueSubject<StateConfig<TestState>, Never>
    var currentState: StateConfig<TestState> {
        currentStateSubject.value
    }

    nonisolated var statePublisher: AnyPublisher<TestState, Never> {
        currentStateSubject.map(\.identifier).eraseToAnyPublisher()
    }

    var state: TestState {
        currentState.identifier
    }

    var suspended = false

    init(states: [StateConfig<TestState>] = [
        StateConfig(.aaa, canTransitionTo: .bbb),
        StateConfig(.bbb, canTransitionTo: .ccc),
        StateConfig(.ccc, canTransitionTo: .aaa),
    ]) {
        initialState = states.first!
        stateConfigs = Dictionary(uniqueKeysWithValues: states.map { ($0.identifier, $0) })
        currentStateSubject = CurrentValueSubject(initialState)
    }

    var resetResult: TransitionResult<S>?
    func reset() async throws -> TransitionResult<TestState> { resetResult! }

    var executeResult: TransitionResult<S>?
    func execute(transition _: @escaping () async throws -> TransitionResult<S>) async throws -> TransitionResult<S> { executeResult! }

    func performTransition(toState state: TestState) async throws -> StateConfig<TestState> {
        let previous = currentState
        currentStateSubject.value = stateConfigs[state]!
        return previous
    }

    var transitionResult: TransitionResult<S>?
    func transition() async throws -> TransitionResult<TestState> { transitionResult! }

    var transitionToResult: TransitionResult<S>?
    func transition(to _: TestState) async throws -> TransitionResult<TestState> { transitionToResult! }

    var transitionToStateResult: TransitionResult<S>?
    func transition(toState _: StateConfig<S>, didExit _: DidExitState<S>?, didEnter _: DidEnterState<S>?) async -> TransitionResult<S> { transitionToStateResult! }
}
