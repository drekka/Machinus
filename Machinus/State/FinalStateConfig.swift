//
//  FinalStateConfig.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/6/21.
//  Copyright © 2021 Derek Clarkson. All rights reserved.
//

public final class FinalStateConfig<T>: StateConfig<T> where T: StateIdentifier {
    /**
     Default initialiser for a background state.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter transitionBarrier: A closure that can be used to bar access to this state and trigger a transition failure if it returns false.
     */
    public init(_ identifier: T,
                didEnter: NextStateAction<T>? = nil,
                transitionBarrier: TransitionBarrier<T>? = nil) {
        super.init(identifier, didEnter: didEnter, transitionBarrier: transitionBarrier)
    }
}
