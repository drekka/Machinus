//
//  Machinus.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import Combine
import Foundation
import os
import UIKit

/// Defines the closures called after a state change finishes.
/// - parameter result: A result that either contains the previous state, or an error if the transition failed.
/// - parameter error: Any error generated by the transition.
public typealias TransitionCompletion<T> = (_ result: Result<T, Error>) -> Void where T: StateIdentifier

/// Defines closures called before and after a transition.
/// - parameter fromState: The previous state of the machine.
/// - parameter toState: The next state of the machine.
public typealias DidTransitionAction<T> = (_ fromState: T, _ toState: T) -> Void where T: StateIdentifier

/// Defines a result builder that can be used on the state machines init.
@resultBuilder
struct StateConfigBuilder<T> where T: StateIdentifier {
    static func buildBlock(_ configs: StateConfig<T>...) -> [StateConfig<T>] { configs }
}

/// Possible results of the transition pre-flight.
private enum PreflightResponse<T> where T: StateIdentifier {
    case allow
    case fail(error: StateMachineError)
    case redirect(to: T)
}

private extension BarrierResponse {
    var asPreflightResponse: PreflightResponse<T> {
        switch self {
        case .allow: return .allow
        case .fail: return .fail(error: .transitionDenied)
        case .redirect(to: let redirectState): return .redirect(to: redirectState)
        }
    }
}

// MARK: - Implementation

/// The implementation of a state machine.
public class StateMachine<T> where T: StateIdentifier {

    public typealias Output = T
    public typealias Failure = Never

    private var stateConfigs: [T: StateConfig<T>] = [:]
    private let currentState: CurrentValueSubject<T, Never>
    private let transitionLock = NSLock()
    private let resetState: T

    private var restoreState: T!
    private var backgroundState: T! {
        didSet {
            startWatchingNotifications()
        }
    }

    private var didTransition: DidTransitionAction<T>?
    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    /// Internal for testing.
    var synchronousMode = false

    // MARK: - Public interface

    /// The name of the machine. By default this is a randon UUID combined witt the type of the state identifiers.
    public let name: String

    /// Readonly access to the machine's current state.
    public var state: T {
        currentState.value
    }

    /// If set to true, causes the machine to issue state change notifications through the default notification center.
    public var postNotifications = false

    /// Set to `DispatchQueue.main` by default, this is the queue used for executing transitions. Note that if running in synchronouse mode then this is disabled.
    public var transitionQ = DispatchQueue.main

    // MARK: - Lifecycle

    deinit {
        stopWatchingNotifications()
    }

    /// Convenience initializer which uses a result builder.
    ///
    /// - parameter name: The unqiue name of this state machine. If `nil` then a unique UUID is used. Mostly used in logging.
    /// - parameter didTransition: A closure that is called after every a transition, Takes both the old and new states as arguments.
    /// - parameter state: A builder that defines a list of states.
    public convenience init(name: String? = nil,
                            didTransition: DidTransitionAction<T>? = nil,
                            @StateConfigBuilder<T> withStates states: () -> [StateConfig<T>]) {
        self.init(name: name, didTransition: didTransition, withStates: states())
    }

    /// Convenience initializer which takes 3 or more state configs..
    ///
    /// - parameter name: The unqiue name of this state machine. If `nil` then a unique UUID is used. Mostly used in logging.
    /// - parameter didTransition: A closure that is called after every a transition, Takes both the old and new states as arguments.
    /// - parameters states: At least 3 states that the engine will manage..
    public convenience init(name: String? = nil,
                            didTransition: DidTransitionAction<T>? = nil,
                            withStates states: StateConfig<T>...) {
        self.init(name: name, didTransition: didTransition, withStates: states)
    }

    private init(name: String?,
                 didTransition: DidTransitionAction<T>?,
                 withStates states: [StateConfig<T>]) {

        if states.count < 3 {
            fatalError("🤖 Must have at least 3 state configs")
        }

        self.name = name ?? UUID().uuidString + "<" + String(describing: T.self) + ">"
        self.didTransition = didTransition
        resetState = states[0].identifier
        currentState = CurrentValueSubject(resetState)

        states.forEach { state in

            if stateConfigs.keys.contains(state.identifier) {
                fatalError("🤖 Multiples states detected with key \(state.identifier)")
            }
            stateConfigs[state.identifier] = state

            if state.features.contains(.background) {
                if self.backgroundState != nil {
                    fatalError("🤖 Only one background is allowed per state machine. Both \(String(describing: backgroundState)) and \(String(describing: state)) are defined as background states.")
                }
                self.backgroundState = state.identifier
            }
        }
    }

    /// Resets the state machine to it's initial state which will be the first state the machine was initialised with.
    ///
    /// This also calls the initial state's `didEnter` closure.
    public func reset() {
        queueTransition { [weak self] in

            guard let self else { return }

            os_log(.debug, "🤖 %@: Resetting to initial state", self.name)
            let fromState = self.state
            self.currentState.value = self.resetState
            let stateConfig = self.stateConfig(forState: self.resetState)
            stateConfig.didEnter?(fromState)
        }
    }

    // MARK: - Public transitions requests

    /// Requests a dynamic transition where the dynamic transition closure of the current state is executed to obtain the next state of the machine.
    ///
    /// - parameter completion: A closure that will be executed when the transition is completed.
    public func transition(completion: TransitionCompletion<T>? = nil) {
        queueTransition { [weak self] in

            guard let self else { return }

            guard let dynamicClosure = self.stateConfigs[self.state]?.dynamicTransition else {
                fatalError("🤖 No dynamic transition defined for \(self.state)")
            }
            os_log(.debug, "🤖 %@: Running dynamic transition", self.name)
            self.transitionToState(self.stateConfig(forState: dynamicClosure()), completion: completion)
        }
    }

    /// Requests a transition to a specific state.
    ///
    /// - parameter state: The state to transition to.
    /// - parameter completion: A closure that will be executed when the transition is completed.
    public func transition(to state: T, completion: TransitionCompletion<T>? = nil) {
        queueTransition { [weak self] in

            guard let self else { return }

            self.transitionToState(self.stateConfig(forState: state), completion: completion)
        }
    }

    // MARK: - Internal

    // Queues a transition that locks access then transitions.
    private func queueTransition(_ block: @escaping () -> Void) {

        let execute: () -> Void = { [weak self] in
            guard let self else { return }
            os_log(.debug, "🤖 %@: Initiating transition", self.name)
            self.transitionLock.lock()
            block()
            self.transitionLock.unlock()
        }

        os_log(.debug, "🤖 %@: Adding locked transition block to queue", name)
        if synchronousMode {
            execute()
            return
        }

        transitionQ.async(execute: execute)
    }

    private func startWatchingNotifications() {

        os_log(.debug, "🤖 %@: Watching application background notification", name)
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            os_log(.debug, "🤖 %@: Background notification received", self.name)
            self.transitionToBackground()
        }

        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            os_log(.debug, "🤖 %@: Foreground notification received", self.name)
            self.transitionToForeground()
        }
    }

    private func stopWatchingNotifications() {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Transition logic

    private func transitionToBackground() {
        queueTransition {
            os_log(.debug, "🤖 %@: Transitioning to background state .%@", self.name, String(describing: self.backgroundState))
            self.restoreState = self.state
            self.currentState.value = self.backgroundState
            self.stateConfig(forState: self.backgroundState).didEnter?(self.restoreState)
        }
    }

    private func transitionToForeground() {
        queueTransition {

            var state: T = self.restoreState

            /// Allow for a transition barrier to redirect.

            let restoreStateConfig = self.stateConfig(forState: self.restoreState)
            if let barrier = restoreStateConfig.transitionBarrier,
               case BarrierResponse.redirect(to: let redirectState) = barrier() {
                os_log(.debug, "🤖 %@: Transition barrier of %@ redirecting to %@", self.name, String(describing: self.restoreState), String(describing: redirectState))
                state = redirectState
            }

            os_log(.debug, "🤖 %@: Transitioning to foreground, restoring state .%@", self.name, String(describing: self.restoreState))
            self.currentState.value = state
            self.stateConfig(forState: self.backgroundState).didExit?(state)
            self.restoreState = nil
        }
    }

    private func transitionToState(_ stateConfigGenerator: @autoclosure () -> StateConfig<T>, completion: TransitionCompletion<T>?) {

        let stateConfig = stateConfigGenerator()
        switch preflightTransition(toState: stateConfig) {

        case .fail(error: let error):
            os_log(.debug, "🤖 %@: Preflight failed: %@", name, error.localizedDescription)
            completion?(.failure(error))
            return

        case .redirect(to: let redirectState):
            os_log(.debug, "🤖 %@: Preflight redirecting to: %@", name, String(describing: redirectState))
            transitionToState(self.stateConfig(forState: redirectState), completion: completion)

        case .allow:
            os_log(.debug, "🤖 %@: Preflight passed", name)
            transition(toState: stateConfig, completion: completion)
        }
    }

    private func transition(toState: StateConfig<T>, completion: TransitionCompletion<T>?) {

        os_log(.debug, "🤖 %@: Executing transition ...", name)
        let fromState = stateConfig(forState: state)
        currentState.value = toState.identifier

        fromState.didExit?(toState.identifier)
        toState.didEnter?(fromState.identifier)
        didTransition?(fromState.identifier, toState.identifier)

        if postNotifications {
            NotificationCenter.default.postStateChange(machine: self, oldState: fromState.identifier)
        }

        // Complete with the old state.
        completion?(.success(fromState.identifier))
    }

    private func preflightTransition(toState: StateConfig<T>) -> PreflightResponse<T> {

        os_log(.debug, "🤖 %@: Preflighting transition to .%@", name, String(describing: state))

        let currentStateConfig = stateConfig(forState: state)

        // If the state is the same state then do nothing.
        if currentStateConfig == toState {
            os_log(.debug, "🤖 %@: Already in state %@", name, String(describing: currentStateConfig))
            return .fail(error: .alreadyInState)
        }

        // Check for a final state transition
        if currentStateConfig.features.contains(.final) {
            os_log(.error, "🤖 %@: Final state, cannot transition", name)
            return .fail(error: .finalState)
        }

        /// Process the registered transition barrier.
        if let barrier = toState.transitionBarrier {
            os_log(.debug, "🤖 %@: Executing transition barrier", name)
            return barrier().asPreflightResponse
        }

        guard toState.features.contains(.global) || currentStateConfig.canTransition(toState: toState) else {
            os_log(.debug, "🤖 %@: Illegal transition", name)
            return .fail(error: .illegalTransition)
        }

        return .allow
    }

    private func stateConfig(forState state: T) -> StateConfig<T> {
        guard let stateConfig = stateConfigs[state] else {
            fatalError("🤖 State \(state) not registered with this machine.")
        }
        return stateConfig
    }
}

// MARK: - Combine

/// Extension that provides combine support to the machine.
extension StateMachine: Publisher {
    public func receive<S>(subscriber: S) where S: Subscriber, S.Input == Output, S.Failure == Failure {
        currentState.receive(subscriber: subscriber)
    }
}