//
//  State.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/**
 Adopt this protocol to define a type as being able to define states.
 */
public protocol StateIdentifier: Hashable {}

/**
 Defines the setup of an individual state.
 */
open class StateConfig<T> where T: StateIdentifier {

    /// The unique identifier used to define this state. This will be used in all `Equatable` tests.
    public let identifier: T

    // Accessed during transitions
    private(set) var isFinal = false
    private(set) var beforeLeaving: ((T) -> Void)?
    private(set) var afterLeaving: ((T) -> Void)?
    private(set) var beforeEntering: ((T) -> Void)?
    private(set) var afterEntering: ((T) -> Void)?
    private(set) var dynamicTransition: (() -> T)?
    private(set) var transitionBarrier: () -> Bool = { true }

    private let allowedTransitions: [T]
    private var isGlobal = false

    // MARK: - Lifecycle

    /**
     Default initialiser.

     - Parameter identifier: The unique identifier of the state.
     - Parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
     */
    public init(identifier: T, allowedTransitions: T...) {
        self.identifier = identifier
        self.allowedTransitions = allowedTransitions
    }

    /**
     Returns true if a transition to the specified state is allowed.

     - Parameter toState: The state that is being queried.
     - Returns: true if a transition from this state to the other state is allowed.
     */
    func canTransition(toState: StateConfig<T>) -> Bool {
        return toState.isGlobal || allowedTransitions.contains(toState.identifier)
    }

    // MARK: - Chainable functions

    /**
     Sets a closure that can act as a barrier, deciding whether or not a transition to this state is allowed.

     This closure is called before a transition to a state is executed. If it returns `false` then the transition fails.

     - Parameter barrier: The closure which acts as a barrier to the transition.
     - Returns: self
     */
    @discardableResult public func withTransitionBarrier(_ barrier: @escaping () -> Bool) -> Self {
        self.transitionBarrier = barrier
        return self
    }

    /**
     Chainable function that sets a closure to be called just before a transition leaves a state.

     - Parameter beforeLeaving: A closure to execute before leaving the state.
     - Parameter nextState: The state about to be transitioned to.
     - Returns: self
     */
    @discardableResult public func beforeLeaving(_ beforeLeaving: @escaping (_ nextState: T) -> Void) -> Self {
        self.beforeLeaving = beforeLeaving
        validateFinalState()
        return self
    }

    /**
     Chainable function that sets a closure to be called just after a transition leaves a state.

     - Parameter afterLeaving: A closure to execute after leaving the state.
     - Parameter nextState: The state about to be transitioned to.
     - Returns: self
     */
    @discardableResult public func afterLeaving(_ afterLeaving: @escaping (_ nextState: T) -> Void) -> Self {
        self.afterLeaving = afterLeaving
        validateFinalState()
        return self
    }

    /**
     Chainable function that sets a closure to be called just before a transition enters a state.

     - Parameter beforeEntering: A closure to execute before entering the state.
     - Parameter previousState: The state just transitioned from.
     - Returns: self
     */
    @discardableResult public func beforeEntering(_ beforeEntering: @escaping (_ previousState: T) -> Void) -> Self {
        self.beforeEntering = beforeEntering
        return self
    }

    /**
     Chainable function that sets a closure to be called just after a transition enters a state.

     - Parameter afterEntering: A closure to execute after entering the state.
     - Parameter previousState: The state just transitioned from.
     - Returns: self
     */
    @discardableResult public func afterEntering(_ afterEntering: @escaping (_ previousState: T) -> Void) -> Self {
        self.afterEntering = afterEntering
        return self
    }

    /**
     Sets a closure that can be used to switch to the next state based on the closure's return value.

     - Parameter dynamicTransition: A closure whose return value defines the next state to transition to.
     - Returns: self
     */
    @discardableResult public func withDynamicTransitions( _ dynamicTransition: @escaping () -> T) -> Self {
        self.dynamicTransition = dynamicTransition
        validateFinalState()
        return self
    }

    /**
     When set, defines a state as being global.

     Global states bypass the normal transition checking, thus allowing you to define states that are accessible from any other state.
     Global states are suitable for things like errors.

     - Returns: self.
     */
    @discardableResult public func makeGlobal() -> Self {
        isGlobal = true
        return self
    }

    /**
     When set, defines a state as being a final state.

     One a final state has been entered it cannot be left. Only a machine reset gets you out of a final start. Final states cannot have exit actions or dynamic transitions.

     - Returns: self.
     */
    @discardableResult public func makeFinal() -> Self {
        isFinal = true
        validateFinalState()
        return self
    }

    // MARK: - Internal

    private func validateFinalState() {
        if isFinal && (
            !allowedTransitions.isEmpty
                || beforeLeaving != nil
                || afterLeaving != nil
                || dynamicTransition != nil) {
            fatalError("🤖 Illegal config, final state .\(identifier) cannot have allowedTransitions, leaving or dynamic transition closures.")
        }
    }
}

// MARK: - Hashable

extension StateConfig: Hashable {

    public var hashValue: Int {
        return identifier.hashValue
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
