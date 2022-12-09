//
//  Created by Derek Clarkson on 23/11/2022.
//

import Foundation
@testable import Machinus
import Nimble
import XCTest

#if os(iOS) || os(tvOS)
    class IOSPlatformTests: XCTestCase {

        func testInitWithMultipleBackgroundStatesFails() async throws {
            do {
                _ = try await StateMachine {
                    StateConfig<TestState>(.aaa)
                    StateConfig<TestState>.background(.background) // Background state 1
                    StateConfig<TestState>.background(.ccc) // Background state 2
                }
            } catch StateMachineError<TestState>.configurationError(let message) {
                expect(message) == "Multiple background states detected. Only one is allowed."
            }
        }

        func testMachineGoesIntoBackgroundExp() async throws {

            let aaaDidExit = WaitFlagActor()
            let machineBackgrounded = WaitFlagActor()
            let machine = try await StateMachine {
                StateConfig<TestState>(.aaa, didExit: { _, _, _ in await aaaDidExit.set() }) // Should not be called.
                StateConfig<TestState>(.bbb)
                StateConfig<TestState>.background(.background, didEnter: { _, _, _ in
                    print("Setting")
                    await machineBackgrounded.set()
                })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)
            await expect({ await aaaDidExit.flag }) == false
        }

        func testMachineGoesIntoBackground() async throws {

            let aaaDidExit = WaitFlagActor()
            let machineBackgrounded = WaitFlagActor()
            let machine = try await StateMachine {
                StateConfig<TestState>(.aaa, didExit: { _, _, _ in await aaaDidExit.set() }) // Should not be called.
                StateConfig<TestState>(.bbb)
                StateConfig<TestState>.background(.background, didEnter: { _, _, _ in await machineBackgrounded.set() })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)
            await expect({ await aaaDidExit.flag }) == false
        }

        func testMachineReturnsToForeground() async throws {

            let aaaDidEnter = WaitFlagActor()
            let machineBackgrounded = WaitFlagActor()
            let machineForegrounded = WaitFlagActor()
            let machine = try await StateMachine(name: "Test machine") {
                StateConfig<TestState>(.aaa, didEnter: { _, _, _ in await aaaDidEnter.set() }) // Should not be called
                StateConfig<TestState>(.bbb)
                StateConfig<TestState>.background(.background,
                                                  didEnter: { _, _, _ in await machineBackgrounded.set() },
                                                  didExit: { _, _, _ in await machineForegrounded.set() })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            await waitFor(await machine.state == .aaa)
            await expect({ await aaaDidEnter.flag }) == false
        }

        func testMachineReturnsToForegroundThenRedirects() async throws {

            let aaaDidEnter = WaitFlagActor()
            let bbbDidEnter = WaitFlagActor()
            let machineBackgrounded = WaitFlagActor()
            let machineForegrounded = WaitFlagActor()
            let machine = try await StateMachine {
                StateConfig<TestState>(.aaa,
                                       didEnter: { _, _, _ in await aaaDidEnter.set() },
                                       transitionBarrier: { _ in .redirect(to: .bbb) }) // Should not be called
                StateConfig<TestState>(.bbb,
                                       didEnter: { _, _, _ in await bbbDidEnter.set() }) // Also should not be called.
                StateConfig<TestState>.background(.background,
                                                  didEnter: { _, _, _ in await machineBackgrounded.set() },
                                                  didExit: { _, _, _ in await machineForegrounded.set() })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            await waitFor(await machine.state == .bbb)
            await expect({ await aaaDidEnter.flag }) == false
            await expect({ await bbbDidEnter.flag }) == false
        }
    }
#endif
