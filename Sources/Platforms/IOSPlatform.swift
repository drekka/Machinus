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
        private var observers: [Any] = []

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        init() {}

        func configure(machine: any Transitionable<S>) async throws {

            // Set the background state.
            let backgroundStates = machine.stateConfigs.values.filter { $0.features.contains(.background) }
            if backgroundStates.endIndex > 1 {
                throw StateMachineError<S>.configurationError("Multiple background states detected. Only one is allowed.")
            }
            guard let backgroundState = backgroundStates.first else {
                // No background state so nothing to observe.
                return
            }

            machine.logger.trace("iOS platform watching for application background notifications")
            await observers.append(
                NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                       object: nil, queue: nil) { [weak machine] _ in
                    guard let machine else { return }
                    Task {
                        machine.logger.trace("iOS platform received background notification")
                        await machine.queue { machine in

                            guard await self.restoreState == nil else {
                                throw StateMachineError<S>.integrityError("Machine already in the background state.")
                            }

                            let previousState = await machine.completeTransition(toState: backgroundState, didExit: nil, didEnter: backgroundState.didEnter)
                            await self.setRestoreState(previousState)
                            return previousState
                        }
                    }
                }
            )

            machine.logger.trace("iOS platform watching for application foreground notifications")
            await observers.append(
                NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                       object: nil, queue: nil) { [weak machine] _ in
                    guard let machine else { return }
                    Task {
                        machine.logger.trace("iOS platform received foreground notification")
                        await machine.queue { machine in

                            guard let toState = await self.restoreState else {
                                throw StateMachineError<S>.integrityError("Restoring from background but no state found to restore to.")
                            }

                            await machine.restore(machine: machine, state: toState, from: backgroundState)
                            await self.setRestoreState(nil)
                            return backgroundState
                        }
                    }
                }
            )
        }

        private func setRestoreState(_ restoreState: StateConfig<S>?) {
            self.restoreState = restoreState
        }
    }

    extension Transitionable {

        /// Recursive restore that allows for a redirect from the restore state barrier.
        func restore(machine: any Transitionable<S>, state: StateConfig<S>, from backgroundState: StateConfig<S>) async {

            /// Allow for a transition barrier to fail or redirect.
            if let barrier = state.transitionBarrier {

                switch await barrier(machine) {

                case .redirect(to: let redirect):
                    guard let redirectState = try? stateConfigs.config(for: redirect) else { return }
                    machine.logger.trace("Transition barrier for \(redirectState) redirecting to \(redirectState))")
                    await restore(machine: machine, state: redirectState, from: backgroundState)
                    return

                case .fail:
                    return

                case .allow:
                    break
                }
            }

            machine.logger.trace("Transitioning to foreground, restoring state \(state)")
            _ = await completeTransition(toState: state, didExit: backgroundState.didExit, didEnter: nil)
        }
    }

#endif
