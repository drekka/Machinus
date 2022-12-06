//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
import os

/// Defines a result builder that can be used on the state machines init.
@resultBuilder
public struct StateConfigBuilder<S> where S: StateIdentifier {
    public static func buildBlock(_ configs: StateConfig<S>...) -> [StateConfig<S>] { configs }
}

/// The implementation of a state machine.
public actor StateMachine<S>: Machine where S: StateIdentifier {

    private let didTransition: MachineDidTransition<S>?
    private var postTransitionNotifications = false
    private let currentStateSubject: CurrentValueSubject<StateConfig<S>, StateMachineError<S>>
    private let platform: any Platform<S>
    private let initialState: StateConfig<S>
    private var currentStateConfig: StateConfig<S> { currentStateSubject.value }

    nonisolated let stateConfigs: [S: StateConfig<S>]

    public nonisolated let name: String
    public var state: S { currentStateConfig.identifier }

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

        self.name = name ?? UUID().uuidString + "<" + String(describing: S.self) + ">"
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
        try await platform.configure(machine: self, executor: self)
    }

    /// If set to true, causes the machine to issue state change notifications through the default notification center.
    public func postNotifications(_ postNotifications: Bool) {
        postTransitionNotifications = postNotifications
    }

    // MARK: - Public transition requests

    /// Resets the state machine to it's initial state which will be the first state the machine was initialised with.
    ///
    /// Note that this is a "hard" reset that ignores `didExit` closures, allow lists and transition barriers. The only code called is the
    /// initial state's `didEnter` closure. everything else is ignored. A ``reset(completion:)`` call does not clear any pending transitions as it
    /// is assumed to be part of the flow.
    @discardableResult
    public func reset() async throws -> S {
        try await execute {
            systemLog.trace("🤖 [\(self.name)] Resetting to initial state")
            return await self.completeTransition(toState: self.initialState, didExit: nil, didEnter: self.initialState.didEnter)
        }.identifier
    }

    /// Requests a dynamic transition where the dynamic transition closure of the current state is executed to obtain the next state of the machine.
    ///
    /// - parameter completion: A closure that will be executed when the transition is completed.
    @discardableResult
    public func transition() async throws -> S {
        try await execute {
            guard let dynamicClosure = self.currentStateConfig.dynamicTransition else {
                throw StateMachineError.noDynamicClosure(self.state)
            }
            systemLog.trace("🤖 [\(self.name)] Running dynamic transition")
            return try await self.transition(toState: await dynamicClosure(self))
        }.identifier
    }

    /// Requests a transition to a specific state.
    ///
    /// - parameter state: The state to transition to.
    /// - parameter completion: A closure that will be executed when the transition is completed.
    @discardableResult
    public func transition(to state: S) async throws -> S {
        try await execute {
            try await self.transition(toState: state)
        }.identifier
    }

    // MARK: - Transition sequence

    @discardableResult
    func execute(transition: @escaping () async throws -> StateConfig<S>) async throws -> StateConfig<S> {
        do {
            return try await transition()
        } catch let error as StateMachineError<S> {
            throw error
        } catch {
            systemLog.trace("🤖 [\(self.name)] Unexpected error detected: \(error.localizedDescription).")
            throw StateMachineError<S>.unexpectedError(error)
        }
    }

    private func transition(toState newState: S) async throws -> StateConfig<S> {

        let nextState = try stateConfigs.config(for: newState)

        switch await currentStateConfig.preflightTransition(toState: nextState, inMachine: self) {

        case .fail(error: let error):
            systemLog.trace("🤖 [\(self.name)] Preflight failed: \(error.localizedDescription)")
            throw error

        case .redirect(to: let redirectState):
            systemLog.trace("🤖 [\(self.name)] Preflight redirecting to: \(redirectState.loggingIdentifier)")
            return try await transition(toState: redirectState)

        case .allow:
            break
        }

        systemLog.trace("🤖 [\(self.name)] Preflight passed, transitioning ...")
        let previousState = state
        let fromState = await completeTransition(toState: nextState, didExit: currentStateConfig.didExit, didEnter: nextState.didEnter)

        if postTransitionNotifications {
            await NotificationCenter.default.postStateChange(machine: self, oldState: previousState)
        }
        return fromState
    }

    func completeTransition(toState: StateConfig<S>, didExit: DidExitState<S>?, didEnter: DidEnterState<S>?) async -> StateConfig<S> {

        systemLog.trace("🤖 [\(self.name)] Transitioning to \(toState)")

        let fromState = currentStateConfig

        // State change
        currentStateSubject.value = toState
        await didExit?(self, toState.identifier)
        await didEnter?(self, fromState.identifier)
        await didTransition?(self, fromState.identifier)
        return fromState
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

// MARK: - Combine

/// Extension that provides combine support to the machine.
public extension StateMachine {

    /// publishes a stream of states as they change.
    nonisolated var statePublisher: AnyPublisher<S, StateMachineError<S>> {
        currentStateSubject.map(\.identifier).eraseToAnyPublisher()
    }

    /// Provides an async sequence of state changes.
    nonisolated var stateSequence: AsyncThrowingSequence<S, StateMachineError<S>> {
        AsyncThrowingSequence(publisher: statePublisher)
    }
}
