//
//  Machinus.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import os

/// A generalised implementation of the `StateMachine` protocol.
public class Machinus<T>: StateMachine where T: StateIdentifier {

    private var current: State<T>
    private var states: [State<T>]

    private var beforeTransition: ((T, T) -> Void)?
    private var afterTransition: ((T, T) -> Void)?

    private let transitionLock = NSLock()
    private var restoreState: T?

    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    // MARK: Public

    public let name: String

    public var state: T {
        return current.identifier
    }

    public var sameStateAsError: Bool = false

    public var postNotifications: Bool = false

    public var transitionQ: DispatchQueue = DispatchQueue.main

    public var backgroundState: T? {
        didSet {
            guard let backgroundState = backgroundState else {
                stopWatchingNotifications()
                return
            }

            os_log("🤖 Setting .%@ as the background state.", type: .debug, String(describing: backgroundState))
            _ = state(forIdentifier: backgroundState)

            backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                guard let self = self else { return }
                os_log("🤖 Transitioning to background state .%@", type: .debug, String(describing: backgroundState))
                self.transition(toState: backgroundState) { restoreState, _ in
                    self.restoreState = restoreState
                }
            }
            foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
                guard let self = self, let restoreState = self.restoreState else { return }
                os_log("🤖 Restoring state .%@", type: .debug, String(describing: backgroundState))
                self.transition(toState: restoreState) { _, _ in
                    self.restoreState = nil
                }
            }
        }
    }

    // MARK: - Lifecycle

    deinit {
        stopWatchingNotifications()
    }

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
        guard let dynamicClosure = current.dynamicTransition else {
            completion(nil, MachinusError.dynamicTransitionNotDefined)
            return
        }
        runTransition(nextState: dynamicClosure, completion: completion)
    }

    public func transition(toState: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {
        runTransition(nextState: { toState }, completion: completion)
    }

    // MARK: - Internal

    private func stopWatchingNotifications() {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private func runTransition(nextState: @escaping () -> T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {

        transitionQ.async { [weak self] in

            guard let self = self else { return }

            // Use a lock to defend against concurrent dispatch queue execution.
            self.transitionLock.lock()
            let toStateIdentifier = nextState()

            os_log("🤖 Transitioning to .%@", type: .debug, String(describing: toStateIdentifier))
            if let toState = self.preflightTransition(toState: toStateIdentifier, completion: completion) {
                self.executeTransition(toState: toState, completion: completion)
            }

            self.transitionLock.unlock()
        }

    }

    private func state(forIdentifier identifier: T) -> State<T> {
        guard let state = states.first(where: { $0.identifier == identifier }) else {
            fatalError("🤖 .\(identifier) is an unknown state.")
        }
        return state
    }

    private func isBackgroundTransition(toOrFromState state: T) -> Bool {
        guard let backgroundState = backgroundState else { return false }
        return state == backgroundState || current == backgroundState
    }

    private func preflightTransition(toState toStateIdentifier: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) -> State<T>? {

        os_log("🤖 Pre-flighting transition ...", type: .debug)

        let newState = state(forIdentifier: toStateIdentifier)

        // If the state is the same state then do nothing.
        guard current != toStateIdentifier else {
            os_log("🤖 Already in state", type: .debug)
            completion(nil, sameStateAsError ? MachinusError.alreadyInState : nil)
            return nil
        }

        // Ignore the rest of the pre-flight if we are about to transition to or from the background state.
        if isBackgroundTransition(toOrFromState: toStateIdentifier) {
            os_log("🤖 Transitioning to or from background state .%@", type: .debug, String(describing: backgroundState))
            return newState
        }

        guard newState.transitionBarrier() else {
            os_log("🤖 Transition barrier blocked transition", type: .debug)
            completion(nil, MachinusError.transitionDenied)
            return nil
        }

        guard current.canTransition(toState: newState) else {
            os_log("🤖 Illegal transition", type: .debug)
            completion(nil, MachinusError.illegalTransition)
            return nil
        }

        return newState
    }

    private func executeTransition(toState: State<T>, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {

        os_log("🤖 Executing transition ...", type: .debug)

        let toStateIdentifier = toState.identifier
        let fromState = current
        let fromStateIdentifier = fromState.identifier

        beforeTransition?(fromStateIdentifier, toStateIdentifier)
        fromState.beforeLeaving?(toStateIdentifier)
        toState.beforeEntering?(fromStateIdentifier)

        self.current = toState

        fromState.afterLeaving?(toStateIdentifier)
        toState.afterEntering?(fromStateIdentifier)
        afterTransition?(fromStateIdentifier, toStateIdentifier)

        // Send the notification
        if postNotifications {
            NotificationCenter.default.postStateChange(machine: self, oldState: fromStateIdentifier)
        }

        completion(fromStateIdentifier, nil)
    }
}

// MARK: - Testing

#if DEBUG
extension Machinus {
    func testSet(toState: T) {
        let state = self.state(forIdentifier: toState)
        current = state
    }
}
#endif
