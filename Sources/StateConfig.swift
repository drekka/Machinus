//
//  Created by Derek Clarkson on 11/2/19.
//
import os

/// Used to define config special features.
struct Features: OptionSet {
    let rawValue: Int
    static let final = Features(rawValue: 1 << 0)
    static let global = Features(rawValue: 1 << 1)
    #if os(iOS) || os(tvOS)
        static let background = Features(rawValue: 1 << 2)
    #endif
}

/// Possible responses from a barrier.
public enum BarrierResponse<S> where S: StateIdentifier {

    /// Allow the transition to continue.
    case allow

    /// The transition is disallowed. This should be the default response from all barriers closures. Note though, that when executing the ``StateConfig<S>.exitBarrier``, a transition to a global state will ignore a ``deny`` and allow the transition to continue.
    case deny

    /// Fail the transition with an error.
    case fail(StateMachineError<S>)

    /// Redirects to another state.
    case redirect(to: S)
}

/// Possible results of a transition pre-flight.
enum PreflightResponse<S> where S: StateIdentifier {
    case allow
    case redirect(to: S)
    case fail(StateMachineError<S>)
}

// MARK: - Base type

/**
 Defines the setup of an individual state.
 */
@dynamicMemberLookup
public final class StateConfig<S> where S: StateIdentifier {

    /// The unique identifier used to define this state. This will be used in all `Equatable` tests.
    let identifier: S
    let features: Features

    // Checks if the requested transition is allowed to this state.
    public var entryBarrier: Barrier<S>?

    // Called when exiting this state.
    public var didExit: DidExitState<S>?

    // Called when entering this state.
    public var didEnter: DidEnterState<S>?

    // Allows for dynamic resolution of the next state.
    public var dynamicTransition: DynamicTransition<S>?

    // Used to disallow transitions.
    var exitBarrier: Barrier<S>

    // Stores data associated with the state. This is to support storing data in the machine
    // when we cannot use associated values on enums because then the state won't register.
    private var store: [String: (Any, Bool)] = [:]

    // MARK: - Lifecycle

    /// Convenience initialiser where there is a simple list of states this state can transition to.
    ///
    /// The order of the parameters in this initialiser match the order of processing.
    ///
    /// - parameters:
    ///   - identifier: The unique identifier of the state.
    ///   - entryBarrier: A closure that can defines whether a transition to this state is allowed. It can trigger an error, redirect to another state or allow the transitions to continue.
    ///   - didEnter: Called after entering this state.
    ///   - dynamicTransition: If present, allows the ``StateMachine<S>.transition()`` function to be used to decide which state to transition to.
    ///   - allowedTransitions: A list of states that can be transitioned to.
    ///   - didExit: Called after exiting this state.
    public convenience init(_ identifier: S,
                            entryBarrier: Barrier<S>? = nil,
                            didEnter: DidEnterState<S>? = nil,
                            dynamicTransition: DynamicTransition<S>? = nil,
                            allowedTransitions: S...,
                            didExit: DidExitState<S>? = nil) {
        self.init(identifier,
                  entryBarrier: entryBarrier,
                  didEnter: didEnter,
                  dynamicTransition: dynamicTransition,
                  exitBarrier: allowedTransitions.asExitBarrier(),
                  didExit: didExit)
    }

    /// Convenience initialiser for when there is a custom exit barrier.
    ///
    /// The order of the parameters in this initialiser match the order of processing. A custom exit barrier is mostly used when it's not possible to
    /// specify a simple state list in the other initialisers ``allowedTransitions``.
    ///
    /// - parameters:
    ///   - identifier: The unique identifier of the state.
    ///   - entryBarrier: A closure that can defines whether a transition to this state is allowed. It can trigger an error, redirect to another state or allow the transitions to continue.
    ///   - didEnter: Called after entering this state.
    ///   - dynamicTransition: If present, allows the ``StateMachine<S>.transition()`` function to be used to decide which state to transition to.
    ///   - exitBarrier: Called to decide if the desired transitions is allowed. Is passed the requested state. It can trigger an error, redirect to another state or allow the transitions to continue. This closure is required.
    ///   - didExit: Called after exiting this state.
    public convenience init(_ identifier: S,
                            entryBarrier: Barrier<S>? = nil,
                            didEnter: DidEnterState<S>? = nil,
                            dynamicTransition: DynamicTransition<S>? = nil,
                            exitBarrier: @escaping Barrier<S>,
                            didExit: DidExitState<S>? = nil) {
        self.init(identifier,
                  features: [],
                  entryBarrier: entryBarrier,
                  didEnter: didEnter,
                  dynamicTransition: dynamicTransition,
                  exitBarrier: exitBarrier,
                  didExit: didExit)
    }

    /// Main initialiser
    ///
    /// - parameter identifier: The unique identifier of the state.
    /// - parameter didEnter: A closure to execute after entering this state.
    /// - parameter didExit: A closure that is executed after exiting this state.
    /// - parameter dynamicTransition: A closures that can be used to decide what state to transition to.
    /// - parameter transitionBarrier: A closure that can defines whether the transition to this state is allowed. It can trigger an error, redirect to another state or allow the transitions to continue.
    /// - parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
    private init(_ identifier: S,
                 features: Features,
                 entryBarrier: Barrier<S>?,
                 didEnter: DidEnterState<S>?,
                 dynamicTransition: DynamicTransition<S>?,
                 exitBarrier: @escaping Barrier<S>,
                 didExit: DidExitState<S>?) {
        self.identifier = identifier
        self.features = features
        self.didEnter = didEnter
        self.didExit = didExit
        self.dynamicTransition = dynamicTransition
        self.exitBarrier = exitBarrier
        self.entryBarrier = entryBarrier
    }

    // MARK: - Factories

    #if os(iOS) || os(tvOS)

        /// Builds a background state.
        ///
        /// - parameters:
        ///   - identifier: The unique identifier of the state.
        ///   - didEnter: A closure to execute after entering this state.
        ///   - didExit: A closure that is executed after exiting this state.
        public static func background(_ identifier: S,
                                      didEnter: DidEnterState<S>? = nil,
                                      didExit: DidExitState<S>? = nil) -> StateConfig<S> {
            StateConfig(identifier,
                        features: .background,
                        entryBarrier: nil,
                        didEnter: didEnter,
                        dynamicTransition: nil,
                        exitBarrier: [].asExitBarrier(),
                        didExit: didExit)
        }
    #endif

    ///  Global state factory.
    ///
    ///  - parameters:
    ///    - identifier: The unique identifier of the state.
    ///    - entryBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
    ///    - didEnter: A closure to execute after entering this state.
    ///    - dynamicTransition: A closures that can be used to decide what state to transition to.
    ///    - allowedTransitions: A list of state identifiers for states that can be transitioned to.
    ///    - didExit: A closure that is executed after exiting this state.
    public static func global(_ identifier: S,
                              entryBarrier: Barrier<S>? = nil,
                              didEnter: DidEnterState<S>? = nil,
                              dynamicTransition: DynamicTransition<S>? = nil,
                              allowedTransitions: S...,
                              didExit: DidExitState<S>? = nil) -> StateConfig<S> {
        StateConfig.global(identifier,
                           entryBarrier: entryBarrier,
                           didEnter: didEnter,
                           dynamicTransition: dynamicTransition,
                           exitBarrier: allowedTransitions.asExitBarrier(),
                           didExit: didExit)
    }

    /// Global state factory.
    ///
    /// - parameters:
    ///   - identifier: The unique identifier of the state.
    ///   - entryBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
    ///   - didEnter: A closure to execute after entering this state.
    ///   - dynamicTransition: A closures that can be used to decide what state to transition to.
    ///   - exitBarrier: Called to decide if the desired transitions is allowed. Is passed the requested state. It can trigger an error, redirect to another state or allow the transitions to continue. This closure is required.
    ///   - didExit: A closure that is executed after exiting this state.
    public static func global(_ identifier: S,
                              entryBarrier: Barrier<S>? = nil,
                              didEnter: DidEnterState<S>? = nil,
                              dynamicTransition: DynamicTransition<S>? = nil,
                              exitBarrier: @escaping Barrier<S>,
                              didExit: DidExitState<S>? = nil) -> StateConfig<S> {
        StateConfig(identifier,
                    features: .global,
                    entryBarrier: entryBarrier,
                    didEnter: didEnter,
                    dynamicTransition: dynamicTransition,
                    exitBarrier: exitBarrier,
                    didExit: didExit)
    }

    /// Final state factory.
    ///
    /// - parameters:
    ///   - identifier: The unique identifier of the state.
    ///   - didEnter: A closure to execute after entering this state.
    ///   - entryBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
    public static func final(_ identifier: S,
                             entryBarrier: Barrier<S>? = nil,
                             didEnter: DidEnterState<S>? = nil) -> StateConfig<S> {
        StateConfig(identifier,
                    features: .final,
                    entryBarrier: entryBarrier,
                    didEnter: didEnter,
                    dynamicTransition: nil,
                    exitBarrier: [].asExitBarrier(),
                    didExit: nil)
    }

    /// Final state factory.

    /// - parameters:
    ///   - identifier: The unique identifier of the state.
    ///   - didEnter: A closure to execute after entering this state.
    ///   - entryBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
    public static func finalGlobal(_ identifier: S,
                                   entryBarrier: Barrier<S>? = nil,
                                   didEnter: DidEnterState<S>? = nil) -> StateConfig<S> {
        StateConfig(identifier,
                    features: [.global, .final],
                    entryBarrier: entryBarrier,
                    didEnter: didEnter,
                    dynamicTransition: nil,
                    exitBarrier: [].asExitBarrier(),
                    didExit: nil)
    }

    // MARK: - Subscripts

    /// Gets and sets values in the state's local store using dynamic member lookup.
    ///
    /// Data stored via this technique is not preserved when the machine leaves the state.
    /// - parameters:
    ///   - key: The keys to store the value under.
    public subscript<T>(dynamicMember key: String) -> T? {
        get { self[key] }
        set { self[key] = newValue }
    }

    /// Gets and sets values in the state's local store.
    ///
    /// Data stored is by default wiped from the store when the machine leaves the state. However if ``preserve`` is set to true
    /// the data is not cleared.
    /// - parameters:
    ///   - key: The keys to store the value under.
    ///   - preserve: If `true` then when the machine exits this state, the value is not cleared from the store.
    public subscript<T>(key: String, preserve: Bool = false) -> T? {
        get {
            store[key]?.0 as? T
        }
        set {
            if let newValue {
                store[key] = (newValue, preserve)
            } else {
                store.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Internal

    func clearStore() {
        store = store.filter(\.value.1)
    }
}

// MARK: - Hashable

extension StateConfig: Equatable {

    public static func == (lhs: StateConfig<S>, rhs: StateConfig<S>) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

extension Array where Element: StateIdentifier {

    func asExitBarrier() -> Barrier<Element> {
        { toState in
            contains(where: { $0 == toState }) ? .allow : .deny
        }
    }
}
