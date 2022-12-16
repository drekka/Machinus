//
//  Created by Derek Clarkson on 5/12/2022.
//

import Combine
import Foundation

// Tuple returned from transitions.
public typealias TransitionResult<S> = (from: S, to: S) where S: StateIdentifier

/// Public interface for the state machine.
///
/// This is the public protocol passed to closures.
public protocol Machine<S>: Actor {

    /// The state identifier.
    associatedtype S: StateIdentifier

    /// The current state of the machine.
    var state: S { get async }

    nonisolated var statePublisher: AnyPublisher<S, Never> { get }

    /// Provides an async sequence of state changes.
    nonisolated var stateSequence: ErasedAsyncPublisher<S> { get }

    /// If enabled, posts notifications of state changes.
    func postNotifications(_ postNotifications: Bool)

    /// Resets the state machine to it's initial state which will be the first state the machine was initialised with.
    ///
    /// Note that this is a "hard" reset that ignores `didExit` closures, allow lists and transition barriers. The only code called is the
    /// initial state's `didEnter` closure. everything else is ignored. A ``reset(completion:)`` call does not clear any pending transitions as it
    /// is assumed to be part of the flow.
    /// - returns: A tuple containing the from and to state of the transition.
    @discardableResult
    func reset() async throws -> TransitionResult<S>

    /// Requests a dynamic transition where the dynamic transition closure of the current state is executed to obtain the next state of the machine.
    ///
    /// - returns: A tuple containing the from and to state of the transition.
    @discardableResult
    func transition() async throws -> TransitionResult<S>

    /// Requests a transition to a specific state.
    ///
    /// - parameter state: The state to transition to.
    /// - returns: A tuple containing the from and to state of the transition.
    @discardableResult
    func transition(to state: S) async throws -> TransitionResult<S>
}

public extension Machine {

    /// Provides an async sequence of state changes.
    nonisolated var stateSequence: ErasedAsyncPublisher<S> {
        ErasedAsyncPublisher(publisher: statePublisher)
    }
}

