//
//  BackgroundStateConfig.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/6/21.
//  Copyright © 2021 Derek Clarkson. All rights reserved.
//

/// Background states are automatically transitioned to when the app goes into the background. There can be only one background state added to a state machine.
public final class BackgroundStateConfig<T>: StateConfig<T> where T: StateIdentifier {

    // TODO: find way to restore to different state via closure.

    /**
     Default initialiser for a background state.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     */
    public init(_ identifier: T,
                didEnter: NextStateAction<T>? = nil,
                didExit: PreviousStateAction<T>? = nil) {
        super.init(identifier, didEnter: didEnter, didExit: didExit)
    }
}
