//
//  File.swift
//
//
//  Created by Derek Clarkson on 5/12/2022.
//

import Foundation
import Combine

// Public interface to a state machine.
public protocol Machine<S>: AnyActor {
    associatedtype S: StateIdentifier

    /// The machines name.
    ///
    /// Only used for errors and logging so that we can identify the machine in a multimachine setup.
    nonisolated var name: String { get }

    /// The current state of the machine.
    var state: S { get async }

    /// Resets the state machine to it's initial state which will be the first state the machine was initialised with.
    ///
    /// Note that this is a "hard" reset that ignores `didExit` closures, allow lists and transition barriers. The only code called is the
    /// initial state's `didEnter` closure. everything else is ignored. A ``reset(completion:)`` call does not clear any pending transitions as it
    /// is assumed to be part of the flow.
    @discardableResult
    func reset() async throws -> S

    /// Requests a dynamic transition where the dynamic transition closure of the current state is executed to obtain the next state of the machine.
    ///
    /// - parameter completion: A closure that will be executed when the transition is completed.
    @discardableResult
    func transition() async throws -> S

    /// Requests a transition to a specific state.
    ///
    /// - parameter state: The state to transition to.
    /// - parameter completion: A closure that will be executed when the transition is completed.
    @discardableResult
    func transition(to state: S) async throws -> S
}
