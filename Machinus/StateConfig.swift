//
//  State.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/// Defines an action to be executed against the state being transitioned to.
/// - parameter previousState: The state being left.
public typealias NextStateAction<T> = (_ previousState: T) -> Void where T: StateIdentifier

/// Defines an action to be executed against the state being transitioned from.
/// - parameter nextState: The new stae of the machine.
public typealias PreviousStateAction<T> = (_ nextState: T) -> Void where T: StateIdentifier

/// Closure called to dynamically perform a transition.
public typealias TransitionFactory<T> = () -> T where T: StateIdentifier

public typealias TransitionBarrier<T> = () -> Bool where T: StateIdentifier

// MARK: - Base type

/**
 Defines the setup of an individual state.
 */
public class StateConfig<T> where T: StateIdentifier {

    /// The unique identifier used to define this state. This will be used in all `Equatable` tests.
    public let identifier: T

    private(set) var didExit: PreviousStateAction<T>?
    private(set) var didEnter: NextStateAction<T>?
    private(set) var dynamicTransition: TransitionFactory<T>?
    private(set) var transitionBarrier: TransitionBarrier<T>?

    private let allowedTransitions: [T]

    // MARK: Lifecycle

    /**
     Default initialiser.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     - parameter dynamicTransition: A closures that can be used to decide what state to transition to.
     - parameter transitionBarrier: A closure that can be used to bar access to this state and trigger a transition failure if it returns false.
     - parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
     */
    public init(_ identifier: T,
                didEnter: NextStateAction<T>? = nil,
                didExit: PreviousStateAction<T>? = nil,
                dynamicTransition: TransitionFactory<T>? = nil,
                transitionBarrier: TransitionBarrier<T>? = nil,
                allowedTransitions: T...) {
        self.identifier = identifier
        self.didEnter = didEnter
        self.didExit = didExit
        self.dynamicTransition = dynamicTransition
        self.transitionBarrier = transitionBarrier
        self.allowedTransitions = allowedTransitions
    }

    /**
     Returns true if a transition to the specified state is allowed.

     - parameter toState: The state that is being queried.
     - returns: true if a transition from this state to the other state is allowed.
     */
    func canTransition(toState: StateConfig<T>) -> Bool {
        return allowedTransitions.contains(toState.identifier)
    }
}

// MARK: - Custom debug string convertable

extension StateConfig: CustomDebugStringConvertible {
    public var debugDescription: String {
        return String(describing: identifier)
    }
}

// MARK: - Unique types

/// Background states are automatically transitioned to when the app goes into the background. There can be only one background state added to a state machine.
public final class BackgroundStateConfig<T>: StateConfig<T> where T: StateIdentifier {

    /**
     Default initialiser for a background state.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     */
    public init(_ identifier: T,
                didEnter: @escaping NextStateAction<T> = { _ in },
                didExit: @escaping PreviousStateAction<T> = { _ in }) {
        super.init(identifier, didEnter: didEnter, didExit: didExit)
    }
}

public final class FinalStateConfig<T>: StateConfig<T> where T: StateIdentifier {
    /**
     Default initialiser for a background state.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter transitionBarrier: A closure that can be used to bar access to this state and trigger a transition failure if it returns false.
     */
    public init(_ identifier: T,
                didEnter: @escaping NextStateAction<T> = { _ in },
                transitionBarrier: TransitionBarrier<T>? = nil) {
        super.init(identifier, didEnter: didEnter, transitionBarrier: transitionBarrier)
    }
}

/// Global states do not need to be in allowed transition lists as any other state can transition to them, except for final states which are always final.
public final class GlobalStateConfig<T>: StateConfig<T> where T: StateIdentifier {}

// MARK: - Hashable

extension StateConfig: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    public static func == (lhs: StateConfig<T>, rhs: StateConfig<T>) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    public static func == (lhs: T, rhs: StateConfig<T>) -> Bool {
        return lhs == rhs.identifier
    }

    public static func == (lhs: StateConfig<T>, rhs: T) -> Bool {
        return lhs.identifier == rhs
    }

    public static func != (lhs: T, rhs: StateConfig<T>) -> Bool {
        return lhs != rhs.identifier
    }

    public static func != (lhs: StateConfig<T>, rhs: T) -> Bool {
        return lhs.identifier != rhs
    }
}
