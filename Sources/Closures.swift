//
//  Created by Derek Clarkson on 7/12/2022.
//

import Foundation

/// The closures in this file are listed in the order they are executed.

/// An action set on a state that is called when a dynamically transition is requested.
///
/// This closure is expected to return the state to then transition to.
/// - parameter machine: A reference to the state machine.
public typealias DynamicTransition<S> = @Sendable (_ machine: any Machine<S>) async -> S where S: StateIdentifier

/// Set on a state to act as a barrier to transitions.
///
/// When the machine is going to transition to the state, this closure is called to allow or deny the transition, or to
/// redirect to another state.
/// - parameter machine: A reference to the state machine.
public typealias TransitionBarrier<S> = @Sendable (_ machine: any Machine<S>) async -> BarrierResponse<S> where S: StateIdentifier

/// An action set on a state that is executed when the machine transitions to the state.
/// - parameter machine: A reference to the state machine.
/// - parameter from: The previous state of the machine.
/// - parameter to: The new state of the machine.
public typealias DidEnterState<S> = @Sendable (_ machine: any Machine<S>, _ from: S, _ to: S) async -> Void where S: StateIdentifier

/// An action set on a state that is executed when the machine transitions away from the state.
/// - parameter machine: A reference to the state machine.
/// - parameter from: The previous state of the machine.
/// - parameter to: The new state of the machine.
public typealias DidExitState<S> = @Sendable (_ machine: any Machine<S>, _ from: S, _ to: S) async -> Void where S: StateIdentifier

/// Set on the state machine and called after each successful transition.
///
/// - parameter machine: A reference to the state machine.
/// - parameter from: The previous state of the machine.
/// - parameter to: The new state of the machine.
public typealias MachineDidTransition<S> = @Sendable (_ machine: any Machine<S>, _ from: S, _ to: S) async -> Void where S: StateIdentifier

/// Passed as part of a transition request, this closure is called once the transition has completed or failed.
/// - parameter machine: A reference to the state machine.
/// - parameter result: A ``Result`` with a either a success and a tuple of the `from`/`to` states, or a failure and error.
public typealias TransitionCompleted<S> = @Sendable (_ machine: any Machine<S>, _ result: Result<(from: S, to: S), StateMachineError<S>>) async -> Void where S: StateIdentifier
