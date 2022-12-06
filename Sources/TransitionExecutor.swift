//
//  File.swift
//
//
//  Created by Derek Clarkson on 3/12/2022.
//

import Foundation

/// Provides the platforms with all the access they need to queue up additional transitions.
protocol TransitionExecutor<S>: AnyActor {

    associatedtype S: StateIdentifier

    nonisolated var name: String { get }
    nonisolated var stateConfigs: [S: StateConfig<S>] { get }

    /// Executes a passed transition closure.
    @discardableResult
    func execute(transition: @escaping () async throws -> StateConfig<S>) async throws -> StateConfig<S>

    /// Call within the ``execute(...)`` transition closure to perform the transition, passing the relevant closures to call.
    func completeTransition(toState: StateConfig<S>, didExit: DidExit<S>?, didEnter: DidEnter<S>?) async -> StateConfig<S>
}

extension StateMachine: TransitionExecutor {}
