//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
import os

/// The implementation of a state machine.
public actor StateMachine<S>: Machine, Transitionable where S: StateIdentifier {

    private let didTransition: MachineDidTransition<S>?
    private let currentStateSubject: CurrentValueSubject<StateConfig<S>, Never>
    private let platform: any Platform<S>

    private var postTransitionNotifications = false

    var suspended = false
    var currentState: StateConfig<S> {
        currentStateSubject.value
    }

    nonisolated let stateConfigs: [S: StateConfig<S>]
    nonisolated let initialState: StateConfig<S>

    /// The machines unique logger.
    let logger: Logger

    public var state: S { currentState.identifier }

    /// publishes a stream of states as they change.
    public nonisolated var statePublisher: AnyPublisher<S, Never> {
        currentStateSubject.map(\.identifier).eraseToAnyPublisher()
    }

    // MARK: - Lifecycle

    /// Convenience initialiser which uses a result builder.
    ///
    /// - parameters:
    ///     - name: The unique name of this state machine. If not passed then a unique UUID is used. Mostly used in logging.
    ///     - didTransition: A closure that is called after every a transition, Takes the machine the old state as arguments.
    ///     - state: A builder that defines a list of states.
    public init(name: String? = nil,
                didTransition: MachineDidTransition<S>? = nil,
                @StateConfigBuilder<S> withStates states: () -> [StateConfig<S>]) async throws {

        let logCategory = name ?? UUID().uuidString + "<" + String(describing: S.self) + ">"
        logger = Logger(subsystem: "au.com.derekclarkson.Machinus", category: logCategory + " 🤖")
        self.didTransition = didTransition

        let stateList = states()
        if stateList.count < 3 {
            throw StateMachineError<S>.configurationError("Insufficient state. There must be at least 3 states.")
        }

        initialState = stateList[0]
        currentStateSubject = CurrentValueSubject(initialState)

        let configs = stateList.map { ($0.identifier, $0) }
        stateConfigs = try Dictionary(configs) { left, _ in
            throw StateMachineError<S>.configurationError("Duplicate states detected for identifier \(left).")
        }

        #if os(iOS) || os(tvOS)
            platform = IOSPlatform()
        #else
            platform = MacOSPlatform()
        #endif
        try await platform.configure(machine: self)
    }

    /// If set to true, causes the machine to issue state change notifications through the default notification center.
    public func postNotifications(_ postNotifications: Bool) {
        postTransitionNotifications = postNotifications
    }

    // MARK: - Public transition requests

    @discardableResult
    public func reset() async throws -> TransitionResult<S> {
        try await execute {
            self.logger.trace("Resetting to initial state")
            return await self.transition(toState: self.initialState, didExit: nil, didEnter: self.initialState.didEnter)
        }
    }

    @discardableResult
    public func transition() async throws -> TransitionResult<S> {
        try await execute {
            self.logger.trace("Executing dynamic transition")
            guard let dynamicTransition = self.currentState.dynamicTransition else {
                throw StateMachineError.noDynamicClosure(self.state)
            }
            self.logger.trace("Running dynamic transition")
            return try await self.transition(to: await dynamicTransition())
        }
    }

    @discardableResult
    public func transition(to state: S) async throws -> TransitionResult<S> {
        try await execute {
            self.logger.trace("Executing transition to .\(String(describing: state))")
            let newStateConfig = try await self.preflight(toState: state)
            return await self.transition(toState: newStateConfig, didExit: self.currentState.didExit, didEnter: newStateConfig.didEnter)
        }
    }

    // MARK: - Transition sequence

    func execute(transition: @escaping () async throws -> TransitionResult<S>) async throws -> TransitionResult<S> {

        // If suspended or already executing a transition then bail.
        if suspended {
            logger.error("Machine suspended. Cannot execute transition request.")
            throw StateMachineError<S>.suspended
        }

        do {
            return try await transition()
        } catch let error as StateMachineError<S> {
            logger.trace("Transition failed: \(error.localizedDescription)")
            throw error
        } catch {
            logger.trace("Unexpected error: \(error.localizedDescription).")
            throw StateMachineError<S>.unexpectedError(error)
        }
    }

    func preflight(toState newState: S) async throws -> StateConfig<S> {

        let nextState = try stateConfigs.config(for: newState)
        switch try await currentState.preflightTransition(toState: nextState, inMachine: self) {

        case .redirect(to: let redirectState):
            logger.trace("Preflight redirecting to: .\(String(describing: redirectState))")
            return try await preflight(toState: redirectState)

        case .allow:
            logger.trace("Preflight passed")
            return nextState
        }
    }

    func transition(toState: StateConfig<S>, didExit: DidExitState<S>?, didEnter: DidEnterState<S>?) async -> TransitionResult<S> {

        logger.trace("Transitioning to \(toState)")

        let fromStateIdentifier = currentState.identifier
        let toStateIdentifier = toState.identifier

        // State change
        currentStateSubject.value = toState
        await didExit?(fromStateIdentifier, toStateIdentifier)
        await didEnter?(fromStateIdentifier, toStateIdentifier)
        await didTransition?(fromStateIdentifier, toStateIdentifier)
        if postTransitionNotifications {
            await NotificationCenter.default.postStateChange(machine: self, oldState: fromStateIdentifier)
        }
        logger.trace("Transition completed.")
        return (from: fromStateIdentifier, to: toStateIdentifier)
    }
}

// MARK: - Support

extension Dictionary where Key: StateIdentifier, Value == StateConfig<Key> {

    /// Wrapper around the default subscript that throws if a value is not found.
    func config(for state: Key) throws -> StateConfig<Key> {
        guard let config = self[state] else {
            throw StateMachineError.unknownState(state)
        }
        return config
    }
}

