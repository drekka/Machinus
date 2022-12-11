//
//  Created by Derek Clarkson on 23/11/2022.
//

import Foundation
@testable import Machinus
import Nimble
import XCTest

#if os(iOS) || os(tvOS)
    class IOSPlatformTests: XCTestCase {

        private var log: LogActor!
        private var machine: (any Machine<TestState>)!

        override func setUp() async throws {

            try await super.setUp()

            log = LogActor()
            machine = try await StateMachine { _, from, to in
                await self.log.append("\(from) -> \(to)")
            }
            withStates: {
                StateConfig<TestState>(.aaa,
                                       didEnter: { _, _, _ in await self.log.append("aaaEnter") },
                                       didExit: { _, _, _ in await self.log.append("aaaExit") },
                                       canTransitionTo: .bbb, .ccc)
                StateConfig<TestState>(.bbb,
                                       didEnter: { _, _, _ in await self.log.append("bbbEnter") },
                                       didExit: { _, _, _ in await self.log.append("bbbExit") },
                                       canTransitionTo: .ccc)
                StateConfig<TestState>(.ccc,
                                       didEnter: { _, _, _ in await self.log.append("cccEnter") },
                                       didExit: { _, _, _ in await self.log.append("cccExit") },
                                       transitionBarrier: { machine in
                                           await machine.state == .aaa ? .allow : .redirect(to: .aaa)
                                       },
                                       canTransitionTo: .aaa)
                StateConfig<TestState>.background(.background,
                                                  didEnter: { _, _, _ in await self.log.append("backgroundEnter") },
                                                  didExit: { _, _, _ in await self.log.append("backgroundExit") })
            }
        }

        override func tearDown() {
            machine = nil
            super.tearDown()
        }

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

        func testMachineGoesIntoBackground() async throws {
            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            await waitFor(await machine.state == .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background"]
        }

        func testMachineReturnsToForeground() async throws {

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background"]

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            await waitFor(await machine.state == .aaa)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background", "backgroundExit", "background -> aaa"]
        }

        func testMachineReturnsToForegroundThenRedirects() async throws {

            await machine.testTransition(to: .ccc)
            await expect({ await self.log.entries }) == ["aaaExit", "cccEnter", "aaa -> ccc"]

            log = LogActor()
            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "ccc -> background"]

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            /// Returns to bbb but redirects to aaa
            await waitFor(await machine.state == .aaa)
            await expect({ await self.log.entries }) == ["backgroundEnter", "ccc -> background", "backgroundExit", "background -> aaa"]
        }

        func testMachineSuspendsTransitionsWhenInBackground() async throws {

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await waitFor(await machine.state == .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background"]

            // These should be queued.
            await machine.transition(to: .bbb)

            // Now return to the foreground.
            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            await waitFor(await machine.state == .bbb)
            await expect({ await self.log.entries }) == [
                "backgroundEnter",
                "aaa -> background",
                "backgroundExit",
                "background -> aaa",
                "aaaExit",
                "bbbEnter",
                "aaa -> bbb",
            ]
        }
    }
#endif
