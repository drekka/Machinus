//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
import os
import SwiftUI

#if os(iOS) || os(tvOS)
    import UIKit
#endif

/// The implementation of a state machine.
public class StateMachine<S>: ObservableObject where S: StateIdentifier {

    // Internal state of the machine.
    private enum State {
        case initializing
        case ready
        case background(StateConfig<S>) // Also tracks the state to restore to.
        case resetting
    }

    private let logger: Logger
    private let didTransition: DidTransition<S>?
    private let stateConfigs: [S: StateConfig<S>]
    private let initialState: StateConfig<S>
    private let backgroundState: StateConfig<S>! // Set if iOS/tvOS and background state specified.

    private var machineState: State = .initializing
    private var currentState: CurrentValueSubject<StateConfig<S>, Never>
    private var stateChangeProcess: AnyCancellable?
    private var notificationObservers: [Any] = []

    @Published public private(set) var state: S
    @Published public private(set) var error: StateMachineError<S>?

    public var postTransitionNotifications = false

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Lifecycle

    /// Convenience initialiser which uses a result builder.
    ///
    /// - parameters:
    ///     - name: The unique name of this state machine. If not passed then a unique UUID is used. Mostly used in logging.
    ///     - didTransition: A closure that is called after every a transition, Takes the machine the old state as arguments.
    ///     - state: A builder that defines a list of states.
    public convenience init(name: String? = nil, @StateConfigBuilder<S> withStates states: () -> [StateConfig<S>], didTransition: DidTransition<S>? = nil) {
        self.init(name: name, withStates: states(), didTransition: didTransition)
    }

    public convenience init(name: String? = nil, withStates states: StateConfig<S>..., didTransition: DidTransition<S>? = nil) {
        self.init(name: name, withStates: states, didTransition: didTransition)
    }

    public init(name: String? = nil, withStates states: [StateConfig<S>], didTransition: DidTransition<S>? = nil) {

        let logCategory = name ?? UUID().uuidString + "<" + String(describing: S.self) + ">"
        logger = Logger(subsystem: "au.com.derekclarkson.machinus", category: logCategory + " 🤖")
        self.didTransition = didTransition

        if states.endIndex < 3 {
            fatalError("not enough states. There must be at least 3 for a machine to work.")
        }

        let configs = states.map { ($0.identifier, $0) }
        stateConfigs = Dictionary(configs) { left, _ in
            fatalError("Multiple \(left) states being registered. Each state must have a unique identifier.")
        }

        initialState = states[0]
        currentState = CurrentValueSubject(initialState)
        state = initialState.identifier

        #if os(iOS) || os(tvOS)

            let backgroundStates = states.filter { $0.features.contains(.background) }
            if backgroundStates.endIndex > 1 {
                fatalError("Multiple background states detected. Only one allowed.")
            }

            backgroundState = backgroundStates.first
            if backgroundState != nil {
                logger.trace("iOS platform watching for application background notifications")
                notificationObservers = [
                    NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                        self?.enterBackground()
                    },
                    NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
                        self?.returnToForeGround()
                    },
                ]
            }
        #else
            backgroundState = nil
        #endif

        stateChangeProcess = currentState
            .scan((initialState, initialState)) { ($0.1, $1) }
            .sink { [weak self] fromState, toState in

                guard let self else { return }

                // Abort if the machine is setting up.
                if case .initializing = self.machineState {
                    return
                }

                let fromStateIdentifier = fromState.identifier
                let toStateIdentifier = toState.identifier

                // ensure the from state's data is cleared.
                defer {
                    fromState.clearStore()
                }

                // Set the state
                self.logger.trace("Transitioning to \(toState)")
                self.state = toStateIdentifier
                if self.error != nil {
                    self.error = nil
                }

                // IF resetting we don't call closures.
                if case .resetting = self.machineState {
                    self.logger.trace("Resetting, skipping closures")
                    return
                }

                // If we are transitioning to the background we don't execute the previous state's `didExit`.
                if toState != self.backgroundState {
                    fromState.didExit?(toStateIdentifier)
                }

                // If we are transitioning to the foreground we don't execute the restore state's `didEnter`.
                if fromState != self.backgroundState {
                    toState.didEnter?(fromStateIdentifier)
                }

                self.didTransition?(fromStateIdentifier, toStateIdentifier)
                if self.postTransitionNotifications {
                    NotificationCenter.default.postStateChange(machine: self, oldState: fromStateIdentifier)
                }

                self.logger.trace("Transition completed.")
            }

        // Initialisation done.
        machineState = .ready
    }

    // MARK: - Public transition requests

    public func reset() {
        logger.trace("Resetting to initial state")
        machineState = .resetting
        currentState.value = initialState
        machineState = .ready
    }

    public func transition() {
        execute {
            self.logger.trace("Executing dynamic transition")
            guard let dynamicTransition = self.currentState.value.dynamicTransition else {
                throw StateMachineError.noDynamicClosure(self.state)
            }
            self.logger.trace("Running dynamic transition")
            self.currentState.value = try self.preflight(toState: dynamicTransition())
        }
    }

    public func transition(to state: S) {
        execute {
            self.currentState.value = try self.preflight(toState: state)
        }
    }

    // MARK: - Transition sequence

    private func execute(transition: @escaping () throws -> Void) {
        do {
            try transition()
        } catch let error as StateMachineError<S> {
            logger.trace("Transition failed: \(error.localizedDescription)")
            self.error = error
        } catch {
            logger.trace("Unexpected error: \(error.localizedDescription).")
            self.error = StateMachineError<S>.unexpectedError(error)
        }
    }

    private func preflight(toState requestedState: S) throws -> StateConfig<S> {
        let requestedStateConfig = try config(for: requestedState)
        let newState = try preflightExit(fromState: currentState.value, toState: requestedStateConfig)
        return try preflightEntry(fromState: currentState.value, toState: newState)
    }

    private func preflightExit(fromState: StateConfig<S>, toState: StateConfig<S>) throws -> StateConfig<S> {

        logger.trace("Preflighting exit from \(fromState)")

        if case .background = machineState {
            logger.error("Machine in background. Cannot execute transition request.")
            throw StateMachineError<S>.suspended
        }

        // If the state is the same state then error.
        if fromState == toState {
            logger.trace("Already in state \(fromState)")
            throw StateMachineError<S>.alreadyInState
        }

        // Error if this is a final state.
        if fromState.features.contains(.final) {
            logger.error("Final state, cannot transition out")
            throw StateMachineError<S>.illegalTransition
        }

        // Check the exit barrier, allowing global states to bypass a ``BarrierResponse.disallow`` response.
        switch fromState.exitBarrier(toState.identifier) {

        case .allow:
            return toState

        case .deny where toState.features.contains(.global):
            logger.trace("Global transition")
            return toState

        case .deny:
            throw StateMachineError<S>.illegalTransition

        case .redirect(let redirectState):
            logger.trace("Preflight exit redirecting to: .\(String(describing: redirectState))")
            return try config(for: redirectState)

        case .fail(let error):
            throw error
        }
    }

    private func preflightEntry(fromState: StateConfig<S>, toState: StateConfig<S>) throws -> StateConfig<S> {

        logger.trace("Preflighting entry to \(toState)")

        // Check the target state's entry barrier.
        guard let entryBarrier = toState.entryBarrier else {
            return toState
        }

        logger.trace("Running \(toState) entry barrier")
        switch entryBarrier(fromState.identifier) {

        case .fail(let error):
            throw error

        case .deny:
            throw StateMachineError<S>.transitionDenied

        case .allow:
            return toState

        case .redirect(to: let redirectState):
            logger.trace("Preflight entry redirecting to: .\(String(describing: redirectState))")
            return try preflightEntry(fromState: fromState, toState: try config(for: redirectState))
        }
    }

    private func config(for state: S) throws -> StateConfig<S> {
        guard let config = stateConfigs[state] else {
            throw StateMachineError<S>.unknownState(state)
        }
        return config
    }

    // MARK: - Subscripts

    public subscript(state: S) -> StateConfig<S> {
        guard let config = stateConfigs[state] else {
            fatalError("Unknown state \(state)")
        }
        return config
    }

    #if os(iOS) || os(tvOS)

        // MARK: - iOS/tvOS backgrounding

        private func enterBackground() {
            execute {

                if case .background = self.machineState {
                    return
                }

                self.logger.trace("iOS platform processing background notification, switching to \(self.backgroundState)")
                let restoreState = self.currentState.value
                self.currentState.value = self.backgroundState
                self.machineState = .background(restoreState)
            }
        }

        private func returnToForeGround() {
            execute {

                guard case .background(let restoreState) = self.machineState else {
                    return
                }

                self.logger.trace("iOS platform processing foreground notification, restoring state \(restoreState)")
                self.machineState = .ready
                self.currentState.value = restoreState
            }
        }

    #endif
}
