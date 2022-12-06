//
//  File.swift
//  
//
//  Created by Derek Clarkson on 7/12/2022.
//

import Foundation

/// Set on the state machine and called after each successful transition.
///
/// - parameter machine: A reference to the state machine.
/// - parameter previousState: The previous state of the machine.
public typealias MachineDidTransition<S> = (_ machine: any Machine<S>, _ previousState: S) async -> Void where S: StateIdentifier

/// An action set on a state that is executed when the machine transitions to the state.
/// - parameter machine: A reference to the state machine.
/// - parameter previousState: The state being left.
public typealias DidEnterState<S> = @Sendable (_ machine: any Machine<S>, _ previousState: S) async -> Void where S: StateIdentifier

/// An action set on a state that is executed when the machine transitions away from the state.
/// - parameter machine: A reference to the state machine.
/// - parameter nextState: The new state of the machine.
public typealias DidExitState<S> = @Sendable (_ machine: any Machine<S>, _ nextState: S) async -> Void where S: StateIdentifier

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
