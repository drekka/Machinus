//
//  Created by Derek Clarkson on 21/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/// State machine errors.
public enum StateMachineError<S>: Error where S:StateIdentifier {

    /// Thrown if the machine is asked to transition when in a suspended state.
    case suspended

    /// Thrown if a state change is requested to the current state.
    case alreadyInState

    /// Thrown when an entry barrier rejects the transition request.
    case transitionDenied

    /// Thrown when the exit barrier returns ``BarrierResponse.disallow`` or the the current state is a final state.
    case illegalTransition

    /// Thrown when the requested state for a transition has not been registered with the engine.
    case unknownState(S)

    /// Thrown when a dynamic transition is requested on a state with no dynamic transition closures.
    case noDynamicClosure(S)

    /// Wraps an unexpected error.
    case unexpectedError(Error)

}
