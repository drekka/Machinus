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
                    machine.logger.trace("iOS platform processing background notification")
                    Task {
                        guard await self.restoreState == nil else {
                            machine.logger.error("Cannot background when already backgrounded.")
                            return
                        }
                        await self.setRestoreState(await machine.currentState)
                        _ = try? await machine.background(to: backgroundState)
                    }
                }
            )

            machine.logger.trace("iOS platform watching for application foreground notifications")
            await observers.append(
                NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                       object: nil, queue: nil) { [weak machine] _ in
                    guard let machine else { return }
                    machine.logger.trace("iOS platform processing foreground notification")
                    Task {
                        guard let restoreState = await self.restoreState else {
                            machine.logger.error("Cannot restore when there is no restore state.")
                            return
                        }
                        _ = try? await machine.foreground(to: restoreState, from: backgroundState)
                        await self.setRestoreState(nil)
                    }
                }
            )
        }

        private func setRestoreState(_ restoreState: StateConfig<S>?) {
            self.restoreState = restoreState
        }
    }

    extension Transitionable {

        func background(to backgroundState: StateConfig<S>) async throws -> TransitionResult<S> {
            try await execute {
                self.suspended = true
                self.logger.trace("Entering background state \(backgroundState)")
                return await self.transition(toState: backgroundState, didExit: nil, didEnter: backgroundState.didEnter)
            }
        }

        func foreground(to restoreState: StateConfig<S>, from backgroundState: StateConfig<S>) async throws -> TransitionResult<S> {
            suspended = false
            return try await execute {

                /// Allow for a transition barrier to fail or redirect.
                if let barrier = restoreState.transitionBarrier,
                   case .redirect(to: let redirect) = await barrier(backgroundState.identifier) {
                    let redirectState = try self.stateConfigs.config(for: redirect)
                    self.logger.trace("Transition barrier for \(restoreState) redirecting to \(redirectState))")
                    return try await self.foreground(to: redirectState, from: backgroundState)
                }

                self.logger.trace("Restoring state \(restoreState)")
                return await self.transition(toState: restoreState, didExit: backgroundState.didExit, didEnter: nil)
            }
        }
    }

#endif
