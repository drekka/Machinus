//
//  File.swift
//
//
//  Created by Derek Clarkson on 3/12/2022.
//

import Foundation

/// Provides the API for a machine so it can be accessed in closures and platforms.
protocol Machine<S>: AnyActor {

    associatedtype S: StateIdentifier

    nonisolated var name: String { get }
    nonisolated var stateConfigs: [S: StateConfig<S>] { get }
    nonisolated var initialState: StateConfig<S> { get }
    nonisolated var currentStateConfig: StateConfig<S> { get }
    nonisolated var state: S { get }

    func queue(transition: @escaping (any Machine<S>) async throws -> StateConfig<S>, completion: ((Result<StateConfig<S>, StateMachineError>) -> Void)?) async

    func transition(toState newState: S) async throws -> StateConfig<S>

    func completeTransition(toState: StateConfig<S>, didExit: DidExit<S>?, didEnter: DidEnter<S>?) async -> StateConfig<S>
}

extension StateMachine: Machine {}
