//
//  File.swift
//
//
//  Created by Derek Clarkson on 7/12/2022.
//

import Foundation
import os

/// Applies the protocols to the state machine.
extension StateMachine: Transitionable {}

/// Provides access to internal functions and properties.
protocol Transitionable<S>: Machine {

    /// Accesses a prebuilt logger for the machine.
    var logger: Logger { get }

    /// Returns the current state's config.
    var currentStateConfig: StateConfig<S> { get async }

    /// Access to the state configs.
    nonisolated var stateConfigs: [S: StateConfig<S>] { get }

    /// The initial state of the machine.
    nonisolated var initialState: StateConfig<S> { get }

    /// Queues a passed closure on the transition queue.
    ///
    /// - parameter transition: A closures containing the transition to be executed.
    /// - parameter completion: A closure that will be called once the transition is finished.
    func queue(transition: @escaping (any Transitionable<S>) async throws -> StateConfig<S>, completion: TransitionCompleted<S>?) async

    /// Performs the main transition flow.
    func performTransition(toState newState: S) async throws -> StateConfig<S>

    /// Call within the ``execute(...)`` transition closure to perform the transition, passing the relevant closures to call.
    func completeTransition(toState: StateConfig<S>, didExit: DidExitState<S>?, didEnter: DidEnterState<S>?) async -> StateConfig<S>
}

extension Transitionable {

    /// Queues a passed closure on the transition queue.
    ///
    /// - parameter transition: A closures containing the transition to be executed.
    func queue(transition: @escaping (any Transitionable<S>) async throws -> StateConfig<S>) async {
        await queue(transition: transition, completion: nil)
    }
}
