//
//  Created by Derek Clarkson on 23/11/2022.
//

#if os(iOS) || os(tvOS)

    import Combine
    import Foundation
    import os
    import UIKit

    /// Gives access to the state machines internal functions.
    protocol Machine<State>: AnyObject {
        associatedtype State: StateIdentifier
        var name: String { get }
        var state: State { get }
        func stateConfig(for state: State) -> StateConfig<State>
        func queueTransition(_ block: @escaping () -> Void)
        func transition(toState: State, didExit: DidExitAction<State>?, didEnter: DidEnterAction<State>?)
    }

    /// The implementation of a state machine.
    class IOSStateObserver<T> where T: StateIdentifier {

        // BAck reference to the state machine.
        private weak var machine: (any Machine<T>)?

        private var restoreState: T?
        private let backgroundState: T
        private var backgroundObserver: Any?
        private var foregroundObserver: Any?

        deinit {
            if let backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver)
            }
            if let foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver)
            }
        }

        init?(machine: some Machine<T>, states: [StateConfig<T>]) {

            self.machine = machine

            // Set the background state.
            let backgroundStates = states.filter { $0.features.contains(.background) }

            // Error if there is more than one background state.
            if backgroundStates.endIndex > 1 {
                fatalError("🤖 [\(machine.name)] Only one background is allowed per state machine. Found \(backgroundStates)")
            }

            // We much have a background state
            guard let state = backgroundStates.first else {
                return nil
            }
            backgroundState = state.identifier

            systemLog.trace("🤖 [\(machine.name)] Watching application background notification")
            backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self, weak machine] _ in
                guard let self, let machine else { return }
                systemLog.trace("🤖 [\(machine.name)] Background notification received")
                self.transitionToBackground()
            }

            foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self, weak machine] _ in
                guard let self, let machine else { return }
                systemLog.trace("🤖 [\(machine.name)] Foreground notification received")
                self.transitionToForeground()
            }
        }

        // MARK: - Transition logic

        private func transitionToBackground() {
            machine?.queueTransition { [weak self, weak machine] in
                guard let self, let machine else { return }
                systemLog.trace("🤖 [\(machine.name)] Transitioning to background state .\(String(describing: self.backgroundState))")
                self.restoreState = machine.state
                machine.transition(toState: self.backgroundState, didExit: nil, didEnter: machine.stateConfig(for: self.backgroundState).didEnter)
            }
        }

        private func transitionToForeground() {
            machine?.queueTransition { [weak self, weak machine] in

                guard let self, let machine, var restoreState = self.restoreState else {
                    return
                }

                /// Allow for a transition barrier to redirect.
                let restoreStateConfig = machine.stateConfig(for: restoreState)
                if let barrier = restoreStateConfig.transitionBarrier,
                   case BarrierResponse.redirect(to: let redirectState) = barrier() {
                    systemLog.trace("🤖 [\(machine.name)] Transition barrier of .\(String(describing: restoreState)) redirecting to .\(String(describing: redirectState))")
                    restoreState = redirectState
                }

                systemLog.trace("🤖 [\(machine.name)] Transitioning to foreground, restoring state .\(String(describing: restoreState))")
                let backgroundStateConfig = machine.stateConfig(for: self.backgroundState)
                machine.transition(toState: restoreState, didExit: backgroundStateConfig.didExit, didEnter: nil)
                self.restoreState = nil
            }
        }
    }

#endif
