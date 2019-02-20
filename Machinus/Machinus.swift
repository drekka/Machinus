//
//  Machinus.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/// Errors
public enum MachinusError: Error {

    /// Returned when a transition is requested to a state that was not registered.
    case unregisteredState

    /// Returned when the target state is not in the current state's allowed transition list.
    case illegalTransition

    /// Thrown when there is no dynamic transition defined on the current state.
    case dynamicTransitionNotDefined
}

/**
 Defines a state machine.
 */
public protocol StateMachine {

    /// The type that identifies states.
    associatedtype StateIdentifier

    /// The current state.
    var state: StateIdentifier { get }

    /// Defaulting to the main queue, this is the dispatch queue which transition will be executed on.
    var transitionQ: DispatchQueue { get set }

    /**
     Sets a closure which is executed before a transition is processed.

     - Parameter beforeTransition: The closure to execute.
     - Parameter nextState: The state the machine is about to transition to.
     - Returns: self.
    */
    func beforeTransition(_ beforeTransition: @escaping (_ nextState: StateIdentifier) -> Void) -> Self

    /**
     Sets a closure which is executed after a transition is processed.

     - Parameter afterTransition: The closure to execute.
     - Parameter previousState: The state the machine just transitioned from.
     - Returns: self.
     */
    func afterTransition(_ beforeTransition: @escaping (_ previousState: StateIdentifier) -> Void) -> Self

    /**
     Execute a transition to a specific state.

     - Parameter toState: The state to transition to.
     - Parameter completion: A closure which is called after the transiton succeeds or fails.
     - Parameter previousState: If the transition was successful, this is the previous state of the machine.
     - Parameter error: If teh transition was not successful, this is the error generated.
     */
    func transition(toState: StateIdentifier, completion: @escaping (_ previousState: StateIdentifier?, _ error: Error?) -> Void)

    /**
     Execute a transition using the current state's dynamic transition closure.

     - Parameter completion: A closure which is called after the transiton succeeds or fails.
     - Parameter previousState: If the transition was successful, this is the previous state of the machine.
     - Parameter error: If teh transition was not successful, this is the error generated.
     */
    func transition(completion: @escaping (_ previousState: StateIdentifier?, _ error: Error?) -> Void)

    /// Resets the machine to it's initial state without running any before and after closures.
    func reset()
}

// MARK: -

/// A generalised implementation of the `StateMachine` protocol.
open class Machinus<T>: StateMachine where T: StateIdentifier {

    private var current: State<T>
    private var states: [State<T>]

    private var beforeTransition: ((T) -> Void)?
    private var afterTransition: ((T) -> Void)?

    public let name: String

    public var state: T {
        return current.identifier
    }

    public var transitionQ: DispatchQueue = DispatchQueue.main

    // MARK: - Lifecycle

    init(name: String = UUID().uuidString + String(describing: T.self),
         withStates firstState: State<T>,
         _ otherStates: State<T>...) {

        guard !otherStates.isEmpty else {
            fatalError("A state machine with only one state isn't much use.")
        }

        self.name = name
        let states:[State<T>] = [firstState] + otherStates

        self.states = states
        self.current = firstState

        if Set(self.states.map { $0.identifier }).count != self.states.count {
            fatalError("More than one state is using the same identifier")
        }
    }

    public func beforeTransition(_ beforeTransition: @escaping (T) -> Void) -> Self {
        self.beforeTransition = beforeTransition
        return self
    }

    public func afterTransition(_ afterTransition: @escaping (T) -> Void) -> Self {
        self.afterTransition = afterTransition
        return self
    }

    public func reset() {
        current = states[0]
    }

    // MARK: - Transitions

    public func transition(completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {

        transitionQ.async { [weak self] in

            guard let self = self else { return }

            guard let toState = self.current.dynamicTransition?() else {
                completion(nil, MachinusError.dynamicTransitionNotDefined)
                return
            }

            self.runTransition(toState: toState, completion: completion)
        }
    }

    public func transition(toState: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {
        transitionQ.async { [weak self] in
            self?.runTransition(toState: toState, completion: completion)
        }
    }

    private func runTransition(toState: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {

        let oldState = self.current
        guard let newState = state(forIdentifier: toState) else {
            completion(nil, MachinusError.unregisteredState)
            return
        }

        guard oldState.canTransition(toState: newState) else {
            completion(nil, MachinusError.illegalTransition)
            return
        }

        beforeTransition?(toState)
        oldState.beforeLeaving?(toState)
        newState.beforeEntering?(toState)

        self.current = newState

        let oldIdentifier = oldState.identifier
        oldState.afterLeaving?(oldIdentifier)
        newState.afterEntering?(oldIdentifier)
        afterTransition?(oldIdentifier)

        completion(oldIdentifier, nil)
    }

    private func state(forIdentifier identifier: T) -> State<T>? {
        return states.first { $0.identifier == identifier }
    }
}

#if DEBUG

// MARK: - Testing

extension Machinus {
    func testSet(toState: T) {
        guard let newState = state(forIdentifier: toState) else { fatalError("Unknown state") }
        current = newState
    }
}
#endif
