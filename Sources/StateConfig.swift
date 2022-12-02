//
//  Created by Derek Clarkson on 11/2/19.
//

/// Defines an action to be executed against the state being transitioned to.
/// - parameter machine: A reference to the state machine.
/// - parameter previousState: The state being left.
public typealias DidEnter<S> = (_ machine: StateMachine<S>, _ previousState: S) async -> Void where S: StateIdentifier

/// Defines an action to be executed against the state being transitioned from.
/// - parameter machine: A reference to the state machine.
/// - parameter nextState: The new state of the machine.
public typealias DidExit<S> = (_ machine: StateMachine<S>, _ nextState: S) async -> Void where S: StateIdentifier

/// Closure called to dynamically perform a transition.
public typealias DynamicTransition<S> = () async -> S where S: StateIdentifier

/// Defines the closure that is executed before a transition to a state.
///
/// This closure can deny the transition or even redirect to another state.
/// If redirecting, the machine fails the current transition, then queues a transition to the redirect state.
public typealias TransitionBarrier<S> = () async -> BarrierResponse<S> where S: StateIdentifier

/// Used to define config special features.
struct Features: OptionSet {
    let rawValue: Int
    static let final = Features(rawValue: 1 << 0)
    static let global = Features(rawValue: 1 << 1)
    #if os(iOS) || os(tvOS)
        static let background = Features(rawValue: 1 << 2)
    #endif
}

/// Possible responses from a transition barrier.
public enum BarrierResponse<S> where S: StateIdentifier {

    /// Allow the transition to continue.
    case allow

    /// Fail the transition with an error.
    case fail

    /// Cancel the current transition and then redirect to the specified state.
    case redirect(to: S)
}

// MARK: - Base type

/**
 Defines the setup of an individual state.
 */
public class StateConfig<S> where S: StateIdentifier {

    /// The unique identifier used to define this state. This will be used in all `Equatable` tests.
    let identifier: S
    let features: Features
    let didExit: DidExit<S>?
    let didEnter: DidEnter<S>?
    let dynamicTransition: DynamicTransition<S>?
    let transitionBarrier: TransitionBarrier<S>?
    private let allowedTransitions: [S]

    // MARK: - Lifecycle

    /**
     Default initialiser.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     - parameter dynamicTransition: A closures that can be used to decide what state to transition to.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     - parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
     */
    public convenience init(_ identifier: S,
                            didEnter: DidEnter<S>? = nil,
                            didExit: DidExit<S>? = nil,
                            dynamicTransition: DynamicTransition<S>? = nil,
                            transitionBarrier: TransitionBarrier<S>? = nil,
                            canTransitionTo: S...) {
        self.init(identifier,
                  features: [],
                  didEnter: didEnter,
                  didExit: didExit,
                  dynamicTransition: dynamicTransition,
                  transitionBarrier: transitionBarrier,
                  canTransitionTo: canTransitionTo)
    }

    // Master initialiser
    init(_ identifier: S,
         features: Features,
         didEnter: DidEnter<S>? = nil,
         didExit: DidExit<S>? = nil,
         dynamicTransition: DynamicTransition<S>? = nil,
         transitionBarrier: TransitionBarrier<S>? = nil,
         canTransitionTo: [S] = []) {
        self.identifier = identifier
        self.features = features
        self.didEnter = didEnter
        self.didExit = didExit
        self.dynamicTransition = dynamicTransition
        self.transitionBarrier = transitionBarrier
        allowedTransitions = canTransitionTo
    }

    // MARK: - Factories

    #if os(iOS) || os(tvOS)
        /**
         Builds a background state.

         - parameter identifier: The unique identifier of the state.
         - parameter didEnter: A closure to execute after entering this state.
         - parameter didExit: A closure that is executed after exiting this state.
         */
        public static func background(_ identifier: S,
                                      didEnter: DidEnter<S>? = nil,
                                      didExit: DidExit<S>? = nil) -> StateConfig<S> {
            StateConfig(identifier, features: .background, didEnter: didEnter, didExit: didExit)
        }
    #endif

    /**
     Global state factory.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter didExit: A closure that is executed after exiting this state.
     - parameter dynamicTransition: A closures that can be used to decide what state to transition to.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     - parameter allowedTransitions: A list of state identifiers for states that can be transitioned to.
     */
    public static func global(_ identifier: S,
                              didEnter: DidEnter<S>? = nil,
                              didExit: DidExit<S>? = nil,
                              dynamicTransition: DynamicTransition<S>? = nil,
                              transitionBarrier: TransitionBarrier<S>? = nil,
                              canTransitionTo: S...) -> StateConfig<S> {
        StateConfig(identifier,
                    features: .global,
                    didEnter: didEnter,
                    didExit: didExit,
                    dynamicTransition: dynamicTransition,
                    transitionBarrier: transitionBarrier,
                    canTransitionTo: canTransitionTo)
    }

    /**
     Final state factory.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     */
    public static func final(_ identifier: S,
                             didEnter: DidEnter<S>? = nil,
                             transitionBarrier: TransitionBarrier<S>? = nil) -> StateConfig<S> {
        StateConfig(identifier, features: .final, didEnter: didEnter, transitionBarrier: transitionBarrier)
    }

    /**
     Final state factory.

     - parameter identifier: The unique identifier of the state.
     - parameter didEnter: A closure to execute after entering this state.
     - parameter transitionBarrier: A closure that can be used to bar access to this state. It can trigger an error, redirect to another state or allow the transitions to continue.
     */
    public static func finalGlobal(_ identifier: S,
                                   didEnter: DidEnter<S>? = nil,
                                   transitionBarrier: TransitionBarrier<S>? = nil) -> StateConfig<S> {
        StateConfig(identifier, features: [.global, .final], didEnter: didEnter, transitionBarrier: transitionBarrier)
    }

    // MARK: - Internal

    /**
     Returns true if a transition to the specified state is allowed.

     - parameter toState: The state that is being queried.
     - returns: true if a transition from this state to the other state is allowed.
     */
    func canTransition(toState: StateConfig<S>) -> Bool {
        allowedTransitions.contains(toState.identifier)
    }
}

// MARK: - Hashable

extension StateConfig: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    public static func == (lhs: StateConfig<S>, rhs: StateConfig<S>) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public static func == (lhs: S, rhs: StateConfig<S>) -> Bool {
        lhs == rhs.identifier
    }

    public static func == (lhs: StateConfig<S>, rhs: S) -> Bool {
        lhs.identifier == rhs
    }

    public static func != (lhs: S, rhs: StateConfig<S>) -> Bool {
        lhs != rhs.identifier
    }

    public static func != (lhs: StateConfig<S>, rhs: S) -> Bool {
        lhs.identifier != rhs
    }
}
