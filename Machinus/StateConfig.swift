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

/// Defines the closure that is executed before a transition to a state.
///
/// This closure can deny the transition or even redirect to another state.
/// If redirecting, the machine fails the current transition, then queues a transition to the redirect state.
public typealias TransitionBarrier<T> = () -> BarrierResponse<T> where T: StateIdentifier

/// Used to define config special features.
struct Features: OptionSet {
    let rawValue: Int
    static let background = Features(rawValue: 1 << 0)
    static let final = Features(rawValue: 1 << 1)
    static let global = Features(rawValue: 1 << 2)
}

/// Possible responses from a transition barrier.
public enum BarrierResponse<T> where T: StateIdentifier {

    /// Allow the transition to continue.
    case allow

    /// Fail the transition with an error.
    case fail

    /// Cancel the current transition and then redirect to the specified state.
    case redirect(to: T)
}

// MARK: - Base type

/**
 Defines the setup of an individual state.
 */
public class StateConfig<T> where T: StateIdentifier {

    /// The unique identifier used to define this state. This will be used in all `Equatable` tests.
    let identifier: T
    let features: Features
    let didExit: PreviousStateAction<T>?
    let didEnter: NextStateAction<T>?
    let dynamicTransition: TransitionFactory<T>?
    let transitionBarrier: TransitionBarrier<T>?
    private let allowedTransitions: [T]

    // MARK: - Lifecycle

    /**
     Default initialiser.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     - parameter dynamicTransition: A closures that can be used to decide what state to transition to.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     - parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
     */
    public convenience init(_ identifier: T,
                            didEnter: NextStateAction<T>? = nil,
                            didExit: PreviousStateAction<T>? = nil,
                            dynamicTransition: TransitionFactory<T>? = nil,
                            transitionBarrier: TransitionBarrier<T>? = nil,
                            canTransitionTo: T...) {
        self.init(identifier,
                  features: [],
                  didEnter: didEnter,
                  didExit: didExit,
                  dynamicTransition: dynamicTransition,
                  transitionBarrier: transitionBarrier,
                  canTransitionTo: canTransitionTo)
    }

    // Master initialiser
    init(_ identifier: T,
         features: Features,
         didEnter: NextStateAction<T>? = nil,
         didExit: PreviousStateAction<T>? = nil,
         dynamicTransition: TransitionFactory<T>? = nil,
         transitionBarrier: TransitionBarrier<T>? = nil,
         canTransitionTo: [T] = []) {
        self.identifier = identifier
        self.features = features
        self.didEnter = didEnter
        self.didExit = didExit
        self.dynamicTransition = dynamicTransition
        self.transitionBarrier = transitionBarrier
        allowedTransitions = canTransitionTo
    }

    // MARK: - Factories

    /**
     Builds a background state.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     */
    public static func background(_ identifier: T,
                                  didEnter: NextStateAction<T>? = nil,
                                  didExit: PreviousStateAction<T>? = nil) -> StateConfig<T> {
        return StateConfig(identifier, features: .background, didEnter: didEnter, didExit: didExit)
    }

    /**
     Global state factory.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     - parameter dynamicTransition: A closures that can be used to decide what state to transition to.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     - parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
     */
    public static func global(_ identifier: T,
                              didEnter: NextStateAction<T>? = nil,
                              didExit: PreviousStateAction<T>? = nil,
                              dynamicTransition: TransitionFactory<T>? = nil,
                              transitionBarrier: TransitionBarrier<T>? = nil,
                              canTransitionTo: T...) -> StateConfig<T> {
        return StateConfig(identifier,
                           features: .global,
                           didEnter: didEnter,
                           didExit: didExit,
                           dynamicTransition: dynamicTransition,
                           transitionBarrier: transitionBarrier,
                           canTransitionTo: canTransitionTo)
    }

    /**
     Final state factory.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     */
    public static func final(_ identifier: T,
                             didEnter: NextStateAction<T>? = nil,
                             transitionBarrier: TransitionBarrier<T>? = nil) -> StateConfig<T> {
        return StateConfig(identifier, features: .final, didEnter: didEnter, transitionBarrier: transitionBarrier)
    }

    /**
     Final state factory.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     */
    public static func finalGlobal(_ identifier: T,
                                   didEnter: NextStateAction<T>? = nil,
                                   transitionBarrier: TransitionBarrier<T>? = nil) -> StateConfig<T> {
        return StateConfig(identifier, features: [.global, .final], didEnter: didEnter, transitionBarrier: transitionBarrier)
    }

    // MARK: - Internal

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
