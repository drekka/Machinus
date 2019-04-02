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

    private var states: [StateConfig<T>]

    private var current: StateConfig<T>
    private var restoreState: StateConfig<T>!

    private var beforeTransition: ((T, T) -> Void)?
    private var afterTransition: ((T, T) -> Void)?

    private let transitionLock = NSLock()

    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    // Internal so we can set one for testing.
    var notificationCenter: NotificationCenter = NotificationCenter.default

    // MARK: Public

    public let name: String

    public var state: T {
        return current.identifier
    }

    public var enableSameStateError = false
    public var enableFinalStateTransitionError = false
    public var postNotifications = false

    public var transitionQ: DispatchQueue = DispatchQueue.main

    public var backgroundState: T? {
        didSet {
            guard let backgroundState = backgroundState else {
                stopWatchingNotifications()
                return
            }

            // Validate the state is known and not final
            let background = state(forIdentifier: backgroundState)
            if background.isFinal {
                fatalError("🤖 Background state cannot have final set")
            }

            os_log("🤖 %@: Setting .%@ as the background state.", type: .debug, self.name, String(describing: backgroundState))

            // Adding notification watching for backgrounding and foregrounding.
            backgroundObserver = notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                self?.runSynchronised {
                    guard let self = self else { return }
                    self.transitionToBackground(state: background)
                }
            }

            foregroundObserver = notificationCenter.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
                self?.runSynchronised {
                    guard let self = self else { return }
                    guard let restoreState = self.restoreState else {
                        fatalError("🤖 Returning to foreground and no stored state to restore")
                    }
                    self.transitionToForeground(state: restoreState)
                }
            }
        }
    }

    // MARK: - Lifecycle

    deinit {
        stopWatchingNotifications()
    }

    public init(name: String = UUID().uuidString + "<" + String(describing: T.self) + ">",
                withStates firstState: StateConfig<T>,
                _ secondState: StateConfig<T>,
                _ thirdState: StateConfig<T>,
                _ otherStates: StateConfig<T>...) {

        self.name = name
        let states:[StateConfig<T>] = [firstState, secondState, thirdState] + otherStates

        self.states = states
        self.current = firstState

        if Set(self.states.map { $0.identifier }).count != self.states.count {
            fatalError("🤖 More than one state is using the same identifier")
        }
    }

    @discardableResult public func beforeTransition(_ beforeTransition: @escaping (T, T) -> Void) -> Self {
        self.beforeTransition = beforeTransition
        return self
    }

    @discardableResult public func afterTransition(_ afterTransition: @escaping (T, T) -> Void) -> Self {
        self.afterTransition = afterTransition
        return self
    }

    public func reset() {
        current = states[0]
    }

    // MARK: - Public transitions

    public func transition(completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {
        guard let dynamicClosure = current.dynamicTransition else {
            fatalError("🤖 No dynamic transition defined")
        }
        runTransition(nextState: dynamicClosure, completion: completion)
    }

    public func transition(toState: T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {
        runTransition(nextState: { toState }, completion: completion)
    }

    // MARK: - Internal

    private func stopWatchingNotifications() {
        if let obs = backgroundObserver {
            notificationCenter.removeObserver(obs)
        }
        if let obs = foregroundObserver {
            notificationCenter.removeObserver(obs)
        }
    }

    private func runSynchronised(block: @escaping () -> Void) {
        transitionQ.async {
            // Use a lock to defend against concurrent dispatch queue execution.
            self.transitionLock.lock()
            block()
            self.transitionLock.unlock()
        }
    }

    private func state(forIdentifier identifier: T) -> StateConfig<T> {
        guard let state = states.first(where: { $0.identifier == identifier }) else {
            fatalError("🤖 State .\(identifier) not registered.")
        }
        return state
    }

    private func isBackgroundTransition(withToState state: T) -> Bool {
        guard let backgroundState = backgroundState else { return false }
        return state == backgroundState || current == backgroundState
    }

    // MARK: - Transition logic

    private func runTransition(nextState: @escaping () -> T, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {
        self.runSynchronised { [weak self] in

            guard let self = self else { return }

            let toStateIdentifier = nextState()
            let toState = self.state(forIdentifier: toStateIdentifier)

            os_log("🤖 %@: Transitioning to .%@", type: .debug, self.name, String(describing: toStateIdentifier))
            if let toState = self.preflightTransition(toState: toState, completion: completion) {
                self.transition(toState: toState, completion: completion)
            }
        }
    }

    private func preflightTransition(toState: StateConfig<T>, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) -> StateConfig<T>? {

        os_log("🤖 %@: Pre-flighting transition ...", type: .debug, self.name)

        // If the state is the same state then do nothing.
        guard current != toState.identifier else {
            os_log("🤖 %@: Already in state", type: .debug, self.name)
            completion(nil, enableSameStateError ? MachinusError.alreadyInState : nil)
            return nil
        }

        // Ignore the rest of the pre-flight if we are about to transition to or from the background state.
        if isBackgroundTransition(withToState: toState.identifier) {

            // Background transitions from a final state are automatically ignored.
            if current.isFinal {
                os_log("🤖 %@: Final state cannot transition to the background state. Ignoring request.", type: .info, self.name)
                completion(nil, nil)
                return nil
            }

            os_log("🤖 %@: Transitioning to or from background state .%@, ignoring allowed and barriers.", type: .debug, self.name, String(describing: backgroundState!))
            return toState
        }

        // Check for a final state transition
        if current.isFinal {
            os_log("🤖 %@: Final state, cannot transition", type: .error, self.name)
            completion(nil, enableFinalStateTransitionError ? MachinusError.finalState : nil)
            return nil
        }

        guard toState.transitionBarrier() else {
            os_log("🤖 %@: Transition barrier blocked transition", type: .debug, self.name)
            completion(nil, MachinusError.transitionDenied)
            return nil
        }

        guard current.canTransition(toState: toState) else {
            os_log("🤖 %@: Illegal transition", type: .debug, self.name)
            completion(nil, MachinusError.illegalTransition)
            return nil
        }

        return toState
    }

    private func transition(toState: StateConfig<T>, completion: @escaping (_ previousState: T?, _ error: Error?) -> Void) {

        let fromState = current

        os_log("🤖 %@: Executing transition ...", type: .debug, self.name)

        self.beforeTransition?(fromState.identifier, toState.identifier)
        fromState.beforeLeaving?(toState.identifier)
        toState.beforeEntering?(fromState.identifier)

        self.current = toState

        fromState.afterLeaving?(toState.identifier)
        toState.afterEntering?(fromState.identifier)
        self.afterTransition?(fromState.identifier, toState.identifier)

        if postNotifications {
            NotificationCenter.default.postStateChange(machine: self, oldState: fromState.identifier)
        }
        completion(fromState.identifier, nil)
    }

    private func transitionToBackground(state background: StateConfig<T>) {
        os_log("🤖 %@: Transitioning to background state .%@", type: .debug, self.name, String(describing: background.identifier))
        let fromState = current
        self.restoreState = current
        background.beforeEntering?(fromState.identifier)
        self.current = background
        background.afterEntering?(fromState.identifier)
    }

    private func transitionToForeground(state restoreState: StateConfig<T>) {
        os_log("🤖 %@: Restoring state .%@", type: .debug, self.name, String(describing: restoreState.identifier))
        let fromState = current
        fromState.beforeLeaving?(restoreState.identifier)
        self.current = restoreState
        self.restoreState = nil
        fromState.afterLeaving?(restoreState.identifier)
    }
}

// MARK: - Testing

#if DEBUG
extension Machinus {
    func testSet(toState: T) {
        let state = self.state(forIdentifier: toState)
        current = state
    }
    func testSetBackground() {
        restoreState = current
        current = state(forIdentifier: backgroundState!)
    }
}
#endif
