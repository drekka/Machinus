//
//  Machinus.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

/// Errors
public enum MachinusError: Error {

    /// Returned if a state change is requested to the current state and the sameStateAsError flag is set.
    case alreadyInState

    /// Returned when a transition is requested to a state that was not registered.
    case unregisteredState

    /// Returned when a transition barrier rejects a transition.
    case transitionDenied

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

    /// If true and a transition to the same state is requested an error will be thrown. Otherwise the completion is called with both values as nil.
    var sameStateAsError: Bool { get set }

    /**
     Sets a closure which is executed before a transition is processed.

     - Parameter beforeTransition: The closure to execute.
     - Parameter fromState: The state the machine just transitioned from.
     - Parameter toState: The state the machine just transitioned to.
     - Returns: self.
    */
    func beforeTransition(_ beforeTransition: @escaping (_ fromState: StateIdentifier, _ toState: StateIdentifier) -> Void) -> Self

    /**
     Sets a closure which is executed after a transition is processed.

     - Parameter afterTransition: The closure to execute.
     - Parameter fromState: The state the machine just transitioned from.
     - Parameter toState: The state the machine just transitioned to.
     - Returns: self.
     */
    func afterTransition(_ beforeTransition: @escaping (_ fromState: StateIdentifier, _ toState: StateIdentifier) -> Void) -> Self

    /**
     Execute a transition to a specific state.

     - Parameter toState: The state to transition to.
     - Parameter completion: A closure which is called after the transiton succeeds or fails.
     - Parameter fromState: The state the machine just transitioned from.
     - Parameter toState: The state the machine just transitioned to.
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
public class Machinus<T>: StateMachine where T: StateIdentifier {

    private var current: State<T>
    private var states: [State<T>]

    private var beforeTransition: ((T, T) -> Void)?
    private var afterTransition: ((T, T) -> Void)?

    public let name: String

    private let transitionLock = NSLock()

    public var state: T {
        return current.identifier
    }

    public var sameStateAsError: Bool = false

    public var transitionQ: DispatchQueue = DispatchQueue.main

    // MARK: - Lifecycle

    public init(name: String = UUID().uuidString + "<" + String(describing: T.self) + ">",
         withStates firstState: State<T>,
         _ secondState: State<T>,
         _ thirdState: State<T>,
         _ otherStates: State<T>...) {

        self.name = name
        let states:[State<T>] = [firstState, secondState, thirdState] + otherStates

        self.states = states
        self.current = firstState

        if Set(self.states.map { $0.identifier }).count != self.states.count {
            fatalError("More than one state is using the same identifier")
        }
    }

    public func beforeTransition(_ beforeTransition: @escaping (T, T) -> Void) -> Self {
        self.beforeTransition = beforeTransition
        return self
    }

    public func afterTransition(_ afterTransition: @escaping (T, T) -> Void) -> Self {
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

            // Use a lock to defend against concurrent dispatch queue execution.
            self.transitionLock.lock()
            guard let toState = self.current.dynamicTransition?() else {
                completion(nil, MachinusError.dynamicTransitionNotDefined)
                return
            }
            self.transitionLock.unlock()

            self.runTransition(toState: toState, completion: completion)
        }
    }

    public func transition(toState: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {
        transitionQ.async { [weak self] in
            self?.runTransition(toState: toState, completion: completion)
        }
    }

    private func runTransition(toState toStateIdentifier: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {

        // Use a lock to defend against concurrent dispatch queue execution.
        transitionLock.lock()

        let fromState = self.current
        guard let newState = state(forIdentifier: toStateIdentifier) else {
            completeTransition(completion, previousState: nil, error: MachinusError.unregisteredState)
            return
        }

        let fromStateIdentifier = fromState.identifier

        // If the state is the same state then do nothing.
        guard fromStateIdentifier != toStateIdentifier else {
            completeTransition(completion, previousState: nil, error: sameStateAsError ? MachinusError.alreadyInState : nil)
            return
        }

        guard newState.transitionBarrier() else {
            completeTransition(completion, previousState: nil, error: MachinusError.transitionDenied)
            return
        }

        guard fromState.canTransition(toState: newState) else {
            completeTransition(completion, previousState: nil, error: MachinusError.illegalTransition)
            return
        }

        beforeTransition?(fromStateIdentifier, toStateIdentifier)
        fromState.beforeLeaving?(toStateIdentifier)
        newState.beforeEntering?(fromStateIdentifier)

        self.current = newState

        fromState.afterLeaving?(toStateIdentifier)
        newState.afterEntering?(fromStateIdentifier)
        afterTransition?(fromStateIdentifier, toStateIdentifier)

        completeTransition(completion, previousState: fromStateIdentifier, error: nil)
    }

    private func completeTransition(_ completion: @escaping (_ previousState: T?, _ error: Error?) -> Void, previousState: T?, error: Error?) {
        completion(previousState, error)
        transitionLock.unlock()
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
