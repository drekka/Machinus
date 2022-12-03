//
//  Created by Derek Clarkson on 23/11/2022.
//

#if os(iOS) || os(tvOS)

    import Combine
    import Foundation
    import os
    import UIKit

    /// Provides additional functionality to state machines running on iOS. Primarily the ability to track the
    /// background state of the app and respond to it being moved in and out of the background.
    actor IOSPlatform<S>: Platform where S: StateIdentifier {

        private var restoreState: StateConfig<S>?
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

        /// Mutating from a non-isolated state (ie. from an external task) requires a async method to compile.
        func setRestoreState(_ state: StateConfig<S>?) async {
            restoreState = state
        }

        init() {}

        func configure(for machine: any Machine<S>) async throws {

            // Set the background state.
            let backgroundStates = machine.stateConfigs.values.filter { $0.features.contains(.background) }
            if backgroundStates.endIndex > 1 {
                throw StateMachineError.configurationError("Multiple background states detected. Only one is allowed.")
            }
            guard let backgroundState = backgroundStates.first else {
                // No background state so nothing to observe.
                return
            }

            systemLog.trace("🤖 [\(machine.name)] Watching application background notification")

            backgroundObserver = await NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                                              object: nil,
                                                                              queue: nil) { [weak self, weak machine] _ in
                guard let self, let machine else { return }
                Task {
                    await self.setRestoreState(await machine.transition(toBackground: backgroundState))
                }
            }

            foregroundObserver = await NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                                              object: nil,
                                                                              queue: nil) { [weak self, weak machine] _ in
                guard let self, let machine else { return }
                Task {
                    await machine.restore(self.restoreState, from: backgroundState)
                    await self.setRestoreState(nil)
                }
            }
        }
    }

    extension Machine {

        func transition(toBackground backgroundState: StateConfig<S>) async -> StateConfig<S> {
            await transition(toState: backgroundState, didExit: nil, didEnter: backgroundState.didEnter)
        }

        func restore(_ restoreState: StateConfig<S>?, from backgroundState: StateConfig<S>) async {

            guard let restoreState else { return }

            /// Allow for a transition barrier to fail or redirect.
            if let barrier = restoreState.transitionBarrier {

                switch await barrier() {

                case .redirect(to: let redirect):
                    guard let redirectState = try? stateConfigs.config(for: redirect) else { return }
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
