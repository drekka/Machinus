//
//  File.swift
//
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

    let currentState: CurrentValueSubject<StateConfig<TestState>, StateMachineError<TestState>>
    var currentStateConfig: StateConfig<TestState> {
        currentState.value
    }

    var state: TestState {
        currentStateConfig.identifier
    }

    init(states: [StateConfig<TestState>] = [
        StateConfig(.aaa, canTransitionTo: .bbb),
        StateConfig(.bbb, canTransitionTo: .ccc),
        StateConfig(.ccc, canTransitionTo: .aaa),
    ]) {
        initialState = states.first!
        stateConfigs = Dictionary(uniqueKeysWithValues: states.map { ($0.identifier, $0) })
        currentState = CurrentValueSubject(initialState)
    }

    func reset(completion _: TransitionCompleted<TestState>?) async {}

    func queue(transition _: @escaping (any Transitionable<TestState>) async throws -> StateConfig<TestState>, completion _: TransitionCompleted<TestState>?) async {}

    func performTransition(toState state: TestState) async throws -> StateConfig<TestState> {
        let previous = currentStateConfig
        currentState.value = stateConfigs[state]!
        return previous
    }

    func transition(completion _: TransitionCompleted<TestState>?) async {}

    func transition(to _: TestState, completion _: TransitionCompleted<TestState>?) async {}

    var transitionResult: StateConfig<TestState>?
    func completeTransition(toState _: StateConfig<TestState>, didExit _: DidExitState<TestState>?, didEnter _: DidEnterState<TestState>?) async -> StateConfig<TestState> {
        transitionResult!
    }
}
