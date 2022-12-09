//
//  Created by Derek Clarkson on 5/12/2022.
//

import Combine
import Foundation

/// Public interface for the state machine.
///
/// This is the public protocol passed to closures.
public protocol Machine<S>: AnyActor {

    /// The state identifier.
    associatedtype S: StateIdentifier

    /// The current state of the machine.
    var state: S { get async }

    /// Resets the state machine to it's initial state which will be the first state the machine was initialised with.
    ///
    /// Note that this is a "hard" reset that ignores `didExit` closures, allow lists and transition barriers. The only code called is the
    /// initial state's `didEnter` closure. everything else is ignored. A ``reset(completion:)`` call does not clear any pending transitions as it
    /// is assumed to be part of the flow.
    /// - parameter completion: A closure that will be executed when the transition is completed.
    func reset(completion: TransitionCompleted<S>?) async

    /// Requests a dynamic transition where the dynamic transition closure of the current state is executed to obtain the next state of the machine.
    ///
    /// - parameter completion: A closure that will be executed when the transition is completed.
    func transition(completion: TransitionCompleted<S>?) async

    /// Requests a transition to a specific state.
    ///
    /// - parameter state: The state to transition to.
    /// - parameter completion: A closure that will be executed when the transition is completed.
    func transition(to state: S, completion: TransitionCompleted<S>?) async
}

public extension Machine {

    func reset() async {
        await reset(completion: nil)
    }

    func transition() async {
        await transition(completion: nil)
    }

    func transition(to state: S) async {
        await transition(to: state, completion: nil)
    }
}
