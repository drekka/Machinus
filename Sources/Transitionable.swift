//
//  Created by Derek Clarkson on 7/12/2022.
//

import Foundation
import os

/// Provides access to internal functions and properties.
protocol Transitionable<S>: Machine {

    /// Accesses a prebuilt logger for the machine.
    nonisolated var logger: Logger { get }

    /// When set, stops the machine from processing any more state changes.
    var suspended: Bool { get set }

    /// Returns the current state's config.
    var currentState: StateConfig<S> { get async }

    /// Access to the state configs.
    nonisolated var stateConfigs: [S: StateConfig<S>] { get }

    /// The initial state of the machine.
    nonisolated var initialState: StateConfig<S> { get }

    /// Executes a passed closure containing the transition.
    ///
    /// - parameter transition: A closures containing the transition to be executed. This should return a tuple of the `from` and `to` states or throw an error.
    /// - returns: A tuple containing the from and to state of the transition.
    func execute(transition: @escaping () async throws -> TransitionResult<S>) async throws -> TransitionResult<S>

    /// Call within the ``execute(...)`` transition closure to perform the transition, passing the relevant closures to call.
    /// - parameters:
    ///   - toState: The state to transition to.
    ///   - didExit: The `didExit` closure of the state being left. Not that some transitions pass a `nil` here even when the state being left has a closure.
    ///   - didEnter: The `didEnter` closure of the new state. Not that some transitions pass a `nil` here even when the new state has a closure.
    /// - returns: a tuple of the `from` and `to` state.
    func transition(toState: StateConfig<S>, didExit: DidExitState<S>?, didEnter: DidEnterState<S>?) async -> TransitionResult<S>
}
