//
//  Created by Derek Clarkson on 7/12/2022.
//

import Foundation
import os

/// Provides access to internal functions and properties.
protocol Transitionable<S>: Machine {

    /// Accesses a prebuilt logger for the machine.
    nonisolated var logger: Logger { get }

    /// Returns the current state's config.
    var currentStateConfig: StateConfig<S> { get async }

    /// Access to the state configs.
    nonisolated var stateConfigs: [S: StateConfig<S>] { get }

    /// The initial state of the machine.
    nonisolated var initialState: StateConfig<S> { get }

    /// Enables or disables the execution of transitions.
    ///
    /// When setting to false, thus enabling execution, any queued transitions will automatically be executed.
    func suspend(_ suspended: Bool) async

    /// Queues a passed closure on the transition queue.
    ///
    /// - parameter atHead: If true, queues the transition as the next transition to be executed.
    /// - parameter transition: A closures containing the transition to be executed.
    /// - parameter completion: A closure that will be called once the transition is finished.
    func queue(atHead: Bool, transition: @escaping (any Transitionable<S>) async throws -> StateConfig<S>, completion: TransitionCompleted<S>?) async

    /// Performs the main transition flow.
    func performTransition(toState newState: S) async throws -> StateConfig<S>

    /// Call within the ``execute(...)`` transition closure to perform the transition, passing the relevant closures to call.
    func completeTransition(toState: StateConfig<S>, didExit: DidExitState<S>?, didEnter: DidEnterState<S>?) async -> StateConfig<S>
}

extension Transitionable {

    /// Queues a passed closure on the transition queue.
    ///
    /// - parameter atHead: If true, queues the transition as the next transition to be executed.
    /// - parameter transition: A closures containing the transition to be executed.
    func queue(atHead: Bool, transition: @escaping (any Transitionable<S>) async throws -> StateConfig<S>) async {
        await queue(atHead: atHead, transition: transition, completion: nil)
    }
}
