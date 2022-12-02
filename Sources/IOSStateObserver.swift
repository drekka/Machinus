//
//  Created by Derek Clarkson on 23/11/2022.
//

#if os(iOS) || os(tvOS)

    import Combine
    import Foundation
    import os
    import UIKit

    /// Provides additional functionality to statemachines running on iOS. Primarily the ability to track the
    /// background state of the app and respond to it being moved in and out of the background.
    actor IOSStateObserver<S> where S: StateIdentifier {

        // BAck reference to the state machine.
        private weak var machine: StateMachine<S>?

        private var restoreState: StateConfig<S>?
        private let backgroundState: StateConfig<S>
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

        /// Mutating from a non-ioslated state (ie. from an external task) requires a async method to compile.
        func setRestoreState(_ state: StateConfig<S>?) async {
            restoreState = state
        }

        init?(machine: StateMachine<S>, states: [StateConfig<S>]) async throws {

            self.machine = machine

            // Set the background state.
            let backgroundStates = states.filter { $0.features.contains(.background) }
            guard let background = backgroundStates.first else {
                return nil
            }
            backgroundState = background
            if backgroundStates.endIndex > 1 {
                throw StateMachineError.configurationError("Multiple background states detected. Only one is allowed.")
            }

            systemLog.trace("🤖 [\(machine.name)] Watching application background notification")

            backgroundObserver = await NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                                              object: nil,
                                                                              queue: nil) { _ in
                Task { [weak self, weak machine] in
                    guard let self, let machine else { return }
                    await self.setRestoreState(await machine.transition(toBackground: self.backgroundState))
                }
            }

            foregroundObserver = await NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                                              object: nil,
                                                                              queue: nil) { _ in
                Task { [weak self, weak machine] in
                    guard let self, let machine else { return }
                    await machine.restore(self.restoreState, from: self.backgroundState)
                    await self.setRestoreState(nil)
                }
            }
        }
    }

    extension StateMachine {

        func transition(toBackground backgroundState: StateConfig<S>) async -> StateConfig<S> {
            return await transition(toState: backgroundState, didExit: nil, didEnter: backgroundState.didEnter)
        }

        func restore(_ restoreState: StateConfig<S>?, from backgroundState: StateConfig<S>) async {

            guard let restoreState else { return }

            /// Allow for a transition barrier to fail or redirect.
            if let barrier = restoreState.transitionBarrier {

                switch await barrier() {

                case .redirect(to: let redirect):
                    guard let redirectState = try? stateConfig(for: redirect) else { return }
                    systemLog.trace("🤖 [\(self.name)] Transition barrier for \(restoreState) redirecting to \(redirectState))")
                    await restore(redirectState, from: backgroundState)
                    return

                case .fail:
                    return

                case .allow:
                    break
                }
            }

            systemLog.trace("🤖 [\(self.name)] Transitioning to foreground, restoring state \(restoreState)")
            _ = await transition(toState: restoreState, didExit: backgroundState.didExit, didEnter: nil)
        }
    }

#endif
