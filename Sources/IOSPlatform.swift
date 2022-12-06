//
//  Created by Derek Clarkson on 23/11/2022.
//

#if os(iOS) || os(tvOS)

    import Foundation
    import os
    import UIKit

    /// Provides additional functionality to state machines running on iOS. Primarily the ability to track the
    /// background state of the app and respond to it being moved in and out of the background.
    actor IOSPlatform<S>: Platform where S: StateIdentifier {

        private var restoreState: StateConfig<S>?
        private var backgroundNotificationWatcher: Task<Void, Error>?
        private var foregroundNotificationWatcher: Task<Void, Error>?

        deinit {
            backgroundNotificationWatcher?.cancel()
            foregroundNotificationWatcher?.cancel()
        }

        /// Mutating from a non-isolated state (ie. from an external task) requires a async method to compile.
        private func setRestoreState(_ state: StateConfig<S>?) async {
            restoreState = state
        }

        init() {}

        func configure(machine: any Machine<S>, executor: isolated any TransitionExecutor<S>) async throws {

            // Set the background state.
            let backgroundStates = executor.stateConfigs.values.filter { $0.features.contains(.background) }
            if backgroundStates.endIndex > 1 {
                throw StateMachineError<S>.configurationError("Multiple background states detected. Only one is allowed.")
            }
            guard let backgroundState = backgroundStates.first else {
                // No background state so nothing to observe.
                return
            }

            systemLog.trace("🤖 [\(executor.name)] Watching for application background notification")
            backgroundNotificationWatcher = Task.detached {
                for await _ in NotificationCenter.default.notifications(named: await UIApplication.didEnterBackgroundNotification) {
                    try await executor.execute {
                        let previousState = await executor.completeTransition(toState: backgroundState, didExit: nil, didEnter: backgroundState.didEnter)
                        await self.setRestoreState(previousState)
                        return previousState
                    }
                }
            }

            foregroundNotificationWatcher = Task.detached {
                for await _ in NotificationCenter.default.notifications(named: await UIApplication.willEnterForegroundNotification) {
                    try await executor.execute {

                        guard let toState = await self.restoreState else {
                            throw StateMachineError<S>.integretyError("Restoring from background but no state found to restore to.")
                        }

                        await executor.restore(machine: machine, state: toState, from: backgroundState)
                        await self.setRestoreState(nil)
                        return backgroundState
                    }
                }
            }
        }
    }

    extension TransitionExecutor {

        /// Recursive restore that allows for a redirect from the restore state barrier.
        func restore(machine: any Machine<S>, state: StateConfig<S>, from backgroundState: StateConfig<S>) async {

            /// Allow for a transition barrier to fail or redirect.
            if let barrier = state.transitionBarrier {

                switch await barrier(machine) {

                case .redirect(to: let redirect):
                    guard let redirectState = try? stateConfigs.config(for: redirect) else { return }
                    systemLog.trace("🤖 [\(self.name)] Transition barrier for \(redirectState) redirecting to \(redirectState))")
                    await restore(machine: machine, state: redirectState, from: backgroundState)
                    return

                case .fail:
                    return

                case .allow:
                    break
                }
            }

            systemLog.trace("🤖 [\(self.name)] Transitioning to foreground, restoring state \(state)")
            _ = await completeTransition(toState: state, didExit: backgroundState.didExit, didEnter: nil)
        }
    }

#endif
