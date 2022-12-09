//
//  Created by Derek Clarkson on 23/11/2022.
//

import Combine
import Foundation
import os

/// Used to lock each transition so we don't have concurrency issues.
private actor TransitionLock {
    private var transition: Task<Void, Never>?
    var isExecuting: Bool { transition != nil }
    func executingTransition(_ newTransition: Task<Void, Never>) {
        transition = newTransition
    }

    func transitionFinished() {
        transition = nil
    }
}

/// The implementation of a state machine.
public actor StateMachine<S>: Machine where S: StateIdentifier {

    private let didTransition: MachineDidTransition<S>?
    private let currentStateSubject: CurrentValueSubject<StateConfig<S>, Never>
    private let platform: any Platform<S>

    private var postTransitionNotifications = false
    private var transitionQueue: [(any Transitionable<S>) async -> Void] = []
    private var executingTransition = TransitionLock()

    nonisolated let stateConfigs: [S: StateConfig<S>]
    nonisolated let initialState: StateConfig<S>

    var currentStateConfig: StateConfig<S> { currentStateSubject.value }

    /// The machines unique logger.
    let logger: Logger

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

    public func reset(completion: TransitionCompleted<S>?) async {
        logger.trace("Requesting reset")
        await queue(transition: { machine in
                        machine.logger.trace("Resetting to initial state")
                        return await machine.completeTransition(toState: machine.initialState, didExit: nil, didEnter: machine.initialState.didEnter)
                    },
                    completion: completion)
    }

    public func transition(completion: TransitionCompleted<S>?) async {
        logger.trace("Requesting dynamic transition")
        await queue(transition: { machine in
                        guard let dynamicClosure = await machine.currentStateConfig.dynamicTransition else {
                            throw StateMachineError<S>.noDynamicClosure(await machine.state)
                        }
                        machine.logger.trace("Running dynamic transition")
                        return try await machine.performTransition(toState: await dynamicClosure(machine))
                    },
                    completion: completion)
    }

    public func transition(to state: S, completion: TransitionCompleted<S>?) async {
        logger.trace("Requesting transition to .\(String(describing: state))")
        await queue(transition: { machine in
                        try await machine.performTransition(toState: state)
                    },
                    completion: completion)
    }

    // MARK: - Transition sequence

    func queue(transition: @escaping (any Transitionable<S>) async throws -> StateConfig<S>, completion: TransitionCompleted<S>?) async {
        transitionQueue.insert({ machine in
                                   do {
                                       let priorState = try await transition(machine).identifier
                                       await completion?(machine, .success((from: priorState, to: await machine.state)))
                                   } catch let error as StateMachineError<S> {
                                       await completion?(machine, .failure(error))
                                   } catch {
                                       machine.logger.trace("Unexpected error detected: \(error.localizedDescription).")
                                       await completion?(machine, .failure(StateMachineError<S>.unexpectedError(error)))
                                   }
                               },
                               at: 0)
        await executeNextTransition()
    }

    // Execute the next block. Unless already executing, then ignore.
    private func executeNextTransition() async {

        // If executing bail.
        guard !(await executingTransition.isExecuting) else {
            logger.trace("Transition already in flight, queuing ...")
            return
        }

        if let nextTransition = transitionQueue.popLast() {
            logger.trace("Starting queued transition")
            await executingTransition.executingTransition(Task.detached(priority: .background) { [weak self] in
                guard let self else {
                    return
                }
                await nextTransition(self)
                await self.executingTransition.transitionFinished()
                await self.executeNextTransition()
            })
        }
    }

    func performTransition(toState newState: S) async throws -> StateConfig<S> {

        let nextState = try stateConfigs.config(for: newState)

        switch await currentStateConfig.preflightTransition(toState: nextState, inMachine: self) {

        case .fail(error: let error):
            logger.trace("Preflight failed: \(error.localizedDescription)")
            throw error

        case .redirect(to: let redirectState):
            logger.trace("Preflight redirecting to: .\(String(describing: redirectState))")
            return try await performTransition(toState: redirectState)

        case .allow:
            break
        }

        logger.trace("Preflight passed")
        let previousState = state
        let fromState = await completeTransition(toState: nextState, didExit: currentStateConfig.didExit, didEnter: nextState.didEnter)

        if postTransitionNotifications {
            await NotificationCenter.default.postStateChange(machine: self, oldState: previousState)
        }
        return fromState
    }

    func completeTransition(toState: StateConfig<S>, didExit: DidExitState<S>?, didEnter: DidEnterState<S>?) async -> StateConfig<S> {

        logger.trace("Transitioning to \(toState)")

        let fromState = currentStateConfig

        // State change
        currentStateSubject.value = toState
        await didExit?(self, fromState.identifier, toState.identifier)
        await didEnter?(self, fromState.identifier, toState.identifier)
        await didTransition?(self, fromState.identifier, toState.identifier)
        logger.trace("Transition completed.")
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
    nonisolated var statePublisher: AnyPublisher<S, Never> {
        currentStateSubject.map(\.identifier).eraseToAnyPublisher()
    }

    /// Provides an async sequence of state changes.
    nonisolated var stateSequence: ErasedAsyncPublisher<S> {
        ErasedAsyncPublisher(publisher: statePublisher)
    }
}
