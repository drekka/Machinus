//
//  Created by Derek Clarkson on 21/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/// State machine errors.
public enum StateMachineError<S>: Error, Sendable where S:StateIdentifier {

    /// Thrown when there is an error configuring the machine.
    case configurationError(String)

    /// Thrown if the machine is asked to transition when in a suspended state.
    case suspended

    /// Thrown if a state change is requested to the current state.
    case alreadyInState

    /// Thrown when a transition barrier rejects a transition.
    case transitionDenied

    /// Thrown when the target state is not in the current state's allowed transition list or
    /// a request has been received to transition from a final state.
    case illegalTransition

    /// Thrown when the requested state for a transition has not been registered with the engine.
    case unknownState(S)

    /// Thrown when a dynamic transition is requested on a state with no dynamic transition closures.
    case noDynamicClosure(S)

    /// Wraps an unexpected error.
    case unexpectedError(Error)

}
