//
//  MachinusError.swift
//  Machinus
//
//  Created by Derek Clarkson on 21/3/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/// State machine errors.
public enum MachinusError: Error {

    /// Returned if a state change is requested to the current state and the sameStateAsError flag is set.
    case alreadyInState

    /// Returned when a transition barrier rejects a transition.
    case transitionDenied

    /// Returned when the target state is not in the current state's allowed transition list.
    case illegalTransition

    /// Thrown when there is no dynamic transition defined on the current state.
    case dynamicTransitionNotDefined
}
