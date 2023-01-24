//
//  Created by Derek Clarkson on 7/12/2022.
//

import Foundation

/// The closures in this file are listed in the order they are executed.

/// An action set on a state that is called when a dynamically transition is requested.
///
/// This closure is expected to return the state to then transition to.
public typealias DynamicTransition<S> = () -> S where S: StateIdentifier

/// Set on a state to act as a barrier to transitions.
///
/// When the machine is going to transition to the state, this closure is called to allow or deny the transition, or to
/// redirect to another state. It is passed the current state as an argument.
public typealias Barrier<S> = (S) -> BarrierResponse<S> where S: StateIdentifier

/// An action set on a state that is executed when the machine transitions to the state.
/// - parameter from: The previous state of the machine.
/// - parameter to: The new state of the machine.
public typealias DidEnterState<S> = (_ from: S, _ to: S) -> Void where S: StateIdentifier

/// An action set on a state that is executed when the machine transitions away from the state.
/// - parameter from: The previous state of the machine.
/// - parameter to: The new state of the machine.
public typealias DidExitState<S> = (_ from: S, _ to: S) -> Void where S: StateIdentifier

/// Set on the state machine and called after each successful transition.
///
/// - parameter from: The previous state of the machine.
/// - parameter to: The new state of the machine.
public typealias DidTransition<S> = (_ from: S, _ to: S) -> Void where S: StateIdentifier
