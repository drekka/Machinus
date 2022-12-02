//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
import os

/// The completion closure for a state change request.
/// - parameter result: A result that either contains the previous state, or an error if the transition failed.
public typealias TransitionCompleted<S> = (_ result: Result<S, StateMachineError>) async -> Void where S: StateIdentifier

/// A state machine closure called after each successful transition.
/// - parameter machine: A reference to the state machine.
/// - parameter previousState: The previous state of the machine.
public typealias DidTransition<S> = (_ machine: StateMachine<S>, _ previousState: S) async -> Void where S: StateIdentifier

/// Defines a result builder that can be used on the state machines init.
@resultBuilder
public struct StateConfigBuilder<S> where S: StateIdentifier {
    public static func buildBlock(_ configs: StateConfig<S>...) -> [StateConfig<S>] { configs }
}

/// The implementation of a state machine.
public actor StateMachine<S> where S: StateIdentifier {

    /// Possible results of the transition pre-flight.
    enum PreflightResponse<S> where S: StateIdentifier {
        case allow
        case fail(error: StateMachineError)
        case redirect(to: S)
    }

    private let stateConfigs: [S: StateConfig<S>]
    private let didTransition: DidTransition<S>?
    private let initialState: StateConfig<S>
    private var postTransitionNotifications = false
    private var transitionQueue: [() async -> Void] = []
    private var executingTransition: Task<Void, Error>?
    private let currentStateSubject: CurrentValueSubject<StateConfig<S>, StateMachineError>

    nonisolated var currentStateConfig: StateConfig<S> {
        currentStateSubject.value
    }

    public nonisolated var state: S {
        currentStateConfig.identifier
    }

    #if os(iOS) || os(tvOS)
        var iosStateObserver: IOSStateObserver<S>?
    #endif

    /// The name of the machine. By default this is a random UUID combined with the type of the state identifiers.
    let name: String

    // MARK: - Lifecycle

    /// Convenience initialiser which uses a result builder.
    ///
    /// - parameters:
    ///     - name: The unique name of this state machine. If not passed then a unique UUID is used. Mostly used in logging.
    ///     - queue: The `DispatchQueue` to schedule transitions on. By defaults this is `DispatchQueue.main`.
    ///     - didTransition: A closure that is called after every a transition, Takes both the old and new states as arguments.
    ///     - state: A builder that defines a list of states.
    public init(name: String? = nil,
                queue: DispatchQueue? = nil,
                didTransition: DidTransition<S>? = nil,
                @StateConfigBuilder<S> withStates states: () -> [StateConfig<S>]) async throws {

        self.name = name ?? UUID().uuidString + "<" + String(describing: S.self) + ">"
        self.didTransition = didTransition

        let stateList = states()
        if stateList.count < 3 {
            throw StateMachineError.configurationError("Insufficient state. There must be at least 3 states.")
        }

        initialState = stateList[0]
        currentStateSubject = CurrentValueSubject(initialState)

        let configs = stateList.map { ($0.identifier, $0) }
        stateConfigs = try Dictionary(configs) { left, _ in
            throw StateMachineError.configurationError("Duplicate states detected for identifier \(left).")
        }

        #if os(iOS) || os(tvOS)
            iosStateObserver = try await IOSStateObserver(machine: self, states: stateList)
        #endif
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
    public func reset(completion: ((Result<S, StateMachineError>) -> Void)? = nil) {
        queue(withCompletion: completion) { [weak self] in
            guard let self else { return nil }
            systemLog.trace("🤖 [\(self.name)] Resetting to initial state")
            return await self.transition(toState: self.initialState, didExit: nil, didEnter: self.initialState.didEnter)
        }
    }

    /// Requests a dynamic transition where the dynamic transition closure of the current state is executed to obtain the next state of the machine.
    ///
    /// - parameter completion: A closure that will be executed when the transition is completed.
    public func transition(completion: ((Result<S, StateMachineError>) -> Void)? = nil) {
        queue(withCompletion: completion) { [weak self] in
            guard let self else { return nil }
            guard let dynamicClosure = self.currentStateConfig.dynamicTransition else {
                throw StateMachineError.noDynamicClosure(self.state)
            }
            systemLog.trace("🤖 [\(self.name)] Running dynamic transition")
            return try await self.transitionToState(await dynamicClosure())
        }
    }

    /// Requests a transition to a specific state.
    ///
    /// - parameter state: The state to transition to.
    /// - parameter completion: A closure that will be executed when the transition is completed.
    public func transition(to state: S, completion: ((Result<S, StateMachineError>) -> Void)? = nil) {
        queue(withCompletion: completion) { [weak self] in
            try await self?.transitionToState(state)
        }
    }

    // MARK: - Internal

    private func queue(withCompletion complete: ((Result<S, StateMachineError>) -> Void)?, transition: @escaping () async throws -> StateConfig<S>?) {
        transitionQueue.insert({
                                   do {
                                       guard let priorState = try await transition() else {
                                           return
                                       }
                                       complete?(.success(priorState.identifier))
                                   } catch let error as StateMachineError {
                                       complete?(.failure(error))
                                   } catch {
                                       systemLog.trace("🤖 [\(self.name)] Unexpected error detected: \(error.localizedDescription).")
                                       complete?(.failure(StateMachineError.unexpectedError(error)))
                                   }
                               },
                               at: 0)
        executeNextTransition()
    }

    func stateConfig(for state: S) throws -> StateConfig<S> {
        guard let config = stateConfigs[state] else {
            throw StateMachineError.unknownState(state)
        }
        return config
    }

    // If not already executing, execute the next block.
    private func executeNextTransition() {

        guard executingTransition == nil else {
            systemLog.trace("🤖 [\(self.name)] Transition already in flight, ignoring request.")
            return
        }

        if let nextBlock = transitionQueue.popLast() {
            systemLog.trace("🤖 [\(self.name)] Found pending transition, initiating new task.")
            executingTransition = Task {
                await nextBlock()
                executingTransition = nil
                executeNextTransition()
            }
        }
    }

    private func transitionToState(_ newState: S) async throws -> StateConfig<S> {

        let nextState = try stateConfig(for: newState)

        switch await preflightTransition(fromState: currentStateConfig, toState: nextState) {

        case .fail(error: let error):
            systemLog.trace("🤖 [\(self.name)] Preflight failed: \(error.localizedDescription)")
            throw error

        case .redirect(to: let redirectState):
            systemLog.trace("🤖 [\(self.name)] Preflight redirecting to: \(redirectState.loggingIndentifier)")
            return try await transitionToState(redirectState)

        case .allow:
            systemLog.trace("🤖 [\(self.name)] Preflight passed, transitioning ...")
            let previousState = state
            let fromState = await transition(toState: nextState, didExit: currentStateConfig.didExit, didEnter: nextState.didEnter)

            if postTransitionNotifications {
                await NotificationCenter.default.postStateChange(machine: self, oldState: previousState)
            }
            return fromState
        }
    }

    private func preflightTransition(fromState: StateConfig<S>, toState: StateConfig<S>) async -> PreflightResponse<S> {

        systemLog.trace("🤖 [\(self.name)] Preflighting transition to \(toState)")

        // If the state is the same state then do nothing.
        if fromState == toState {
            systemLog.trace("🤖 [\(self.name)] Already in state \(fromState)")
            return .fail(error: .alreadyInState)
        }

        // Check for a final state transition
        if fromState.features.contains(.final) {
            systemLog.error("🤖 [\(self.name)] Final state, cannot transition")
            return .fail(error: .illegalTransition)
        }

        /// Process the registered transition barrier.
        if let barrier = toState.transitionBarrier {
            systemLog.trace("🤖 [\(self.name)] Executing transition barrier")
            switch await barrier() {
            case .allow: return .allow
            case .fail: return .fail(error: .transitionDenied)
            case .redirect(to: let redirectState): return .redirect(to: redirectState)
            }
        }

        guard toState.features.contains(.global) || fromState.canTransition(toState: toState) else {
            systemLog.trace("🤖 [\(self.name)] Illegal transition")
            return .fail(error: .illegalTransition)
        }

        return .allow
    }

    func transition(toState: StateConfig<S>, didExit: DidExit<S>?, didEnter: DidEnter<S>?) async -> StateConfig<S> {

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

// MARK: - Combine

/// Extension that provides combine support to the machine.
public extension StateMachine {

    /// publishes a stream of states as they change.
    nonisolated var statePublisher: AnyPublisher<S, StateMachineError> {
        currentStateSubject.map(\.identifier).eraseToAnyPublisher()
    }

    /// Provides an async sequence of state changes.
    nonisolated var stateSequence: AsyncThrowingSequence<S, StateMachineError> {
        AsyncThrowingSequence(publisher: statePublisher)
    }
}
