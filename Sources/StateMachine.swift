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

    @Published public var state: S
    @Published public var error: StateMachineError<S>?

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
                if case .initializing = self.machineState { return }

                let fromStateIdentifier = fromState.identifier
                let toStateIdentifier = toState.identifier

                // Set the state
                self.logger.trace("Transitioning to \(toState)")
                self.state = toStateIdentifier
                if self.error != nil {
                    self.error = nil
                }

                // Avoid calling closures if resetting.
                if case .resetting = self.machineState {
                    self.logger.trace("Resetting, skipping closures")
                    return
                }

                // If we are transitioning to the background we don't execute the previous state's `didExit`.
                if toState != self.backgroundState {
                    fromState.didExit?(fromStateIdentifier, toStateIdentifier)
                }

                // If we are transitioning to the foreground we don't execute the restore state's `didEnter`.
                if fromState != self.backgroundState {
                    toState.didEnter?(fromStateIdentifier, toStateIdentifier)
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
            try self.canTransition()
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
            try self.canTransition()
            self.currentState.value = try self.preflight(toState: state)
        }
    }

    // MARK: - Transition sequence

    private func canTransition() throws {
        if case .background = machineState {
            logger.error("Machine in background. Cannot execute transition request.")
            throw StateMachineError<S>.suspended
        }
    }

    private func preflight(toState newState: S) throws -> StateConfig<S> {

        guard let nextState = stateConfigs[newState] else {
            throw StateMachineError.unknownState(newState)
        }

        switch currentState.value.preflightTransition(toState: nextState, logger: logger) {

        case .allow:
            logger.trace("Preflight passed")
            return nextState

        case .redirect(to: let redirectState):
            logger.trace("Preflight redirecting to: .\(String(describing: redirectState))")
            return try preflight(toState: redirectState)

        case .fail(let error):
            throw error
        }
    }

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

    // MARK: - Subscripts

    public subscript(state: S) -> StateConfig<S> {
        guard let config = stateConfigs[state] else {
            fatalError("Unknown state \(state)")
        }
        return config
    }

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
}
