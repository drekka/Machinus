//
//  StateMachine.swift
//  Machinus
//
//  Created by Derek Clarkson on 21/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import Combine

/**
 Defines a state machine.
 */
public protocol StateMachine: Publisher {
    /// The type that identifies states.
    associatedtype StateIdentifier

    /// The current state.
    var state: StateIdentifier { get }

    /// Defaulting to the main queue, this is the dispatch queue which transition will be executed on.
    var transitionQ: DispatchQueue { get set }

    /// If true and a transition to the same state is requested an error will be thrown. Otherwise the completion is called with both values as nil.
    var enableSameStateError: Bool { get set }

    /// If enabled and a transition from a final state is attempted then a MachinusError.finalState error is returned. Otherwise a nil error is returned.
    var enableFinalStateTransitionError: Bool { get set }

    /// If enabled, the engine will send notifications of a state change.
    var postNotifications: Bool { get set }

    /**
     If set, enables the monitoring of application transitions to and from the background, using this state as the background state.

     This is handled by watching the `UIApplication.didEnterBackgroundNotification` and `UIApplication.willEnterForegroundNotification` notifications.
     When the app enters the background, the machine will note the current state then automatically transition to this state. When the app comes back to the foregraund it will transition back to the state it previously noted.

     The state assigned to this property will be configured as a global state to allow easy transitions so there is no need to add it to any of the other states as an allowed transition state. Transition barrier will also be ignore when executing these transitions.
     */
    var backgroundState: StateIdentifier? { get set }

    /**
     Sets a closure which is executed before a transition is processed.

     - Parameter beforeTransition: The closure to execute.
     - Parameter fromState: The state the machine just transitioned from.
     - Parameter toState: The state the machine just transitioned to.
     - Returns: self.
     */
    func beforeTransition(_ beforeTransition: @escaping (_ fromState: StateIdentifier, _ toState: StateIdentifier) -> Void) -> Self

    /**
     Sets a closure which is executed after a transition is processed.

     - Parameter afterTransition: The closure to execute.
     - Parameter fromState: The state the machine just transitioned from.
     - Parameter toState: The state the machine just transitioned to.
     - Returns: self.
     */
    func afterTransition(_ beforeTransition: @escaping (_ fromState: StateIdentifier, _ toState: StateIdentifier) -> Void) -> Self

    /**
     Execute a transition to a specific state.

     - Parameter toState: The state to transition to.
     - Parameter completion: A closure which is called after the transiton succeeds or fails.
     - Parameter fromState: The state the machine just transitioned from.
     - Parameter toState: The state the machine just transitioned to.
     - Parameter error: If teh transition was not successful, this is the error generated.
     */
    func transition(toState: StateIdentifier, completion: @escaping (_ previousState: StateIdentifier?, _ error: Error?) -> Void)

    /**
     Execute a transition using the current state's dynamic transition closure.

     - Parameter completion: A closure which is called after the transiton succeeds or fails.
     - Parameter previousState: If the transition was successful, this is the previous state of the machine.
     - Parameter error: If teh transition was not successful, this is the error generated.
     */
    func transition(completion: @escaping (_ previousState: StateIdentifier?, _ error: Error?) -> Void)

    /// Resets the machine to it's initial state without running any before and after closures.
    func reset()
}
