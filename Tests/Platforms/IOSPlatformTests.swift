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
        private var machine: (any Transitionable<TestState>)!

        override func setUp() async throws {

            try await super.setUp()

            log = LogActor()
            machine = try await StateMachine { from, to in
                await self.log.append("\(from) -> \(to)")
            }
            withStates: {
                StateConfig<TestState>(.aaa,
                                       didEnter: { _, _ in await self.log.append("aaaEnter") },
                                       didExit: { _, _ in await self.log.append("aaaExit") },
                                       canTransitionTo: .bbb, .ccc)
                StateConfig<TestState>(.bbb,
                                       didEnter: { _, _ in await self.log.append("bbbEnter") },
                                       didExit: { _, _ in await self.log.append("bbbExit") },
                                       canTransitionTo: .ccc)
                StateConfig<TestState>(.ccc,
                                       didEnter: { _, _ in await self.log.append("cccEnter") },
                                       didExit: { _, _ in await self.log.append("cccExit") },
                                       transitionBarrier: { $0 == .aaa ? .allow : .redirect(to: .aaa) },
                                       canTransitionTo: .aaa)
                StateConfig<TestState>.background(.background,
                                                  didEnter: { _, _ in await self.log.append("backgroundEnter") },
                                                  didExit: { _, _ in await self.log.append("backgroundExit") })
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
            await machine.waitFor(state: .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background"]
        }

        func testMachineReturnsToForeground() async throws {

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await machine.waitFor(state: .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background"]

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            await machine.waitFor(state: .aaa)
            await expect({ await self.log.entries }) == ["backgroundEnter", "aaa -> background", "backgroundExit", "background -> aaa"]
        }

        func testMachineReturnsToForegroundThenRedirects() async throws {

            await machine.testTransition(to: .ccc)
            await expect({ await self.log.entries }) == ["aaaExit", "cccEnter", "aaa -> ccc"]

            log = LogActor()
            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await machine.waitFor(state: .background)
            await expect({ await self.log.entries }) == ["backgroundEnter", "ccc -> background"]

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            /// Returns to bbb but redirects to aaa
            await machine.waitFor(state: .aaa)
            await expect({ await self.log.entries }) == ["backgroundEnter", "ccc -> background", "backgroundExit", "background -> aaa"]
        }

        func testSuspendedMachineThrows() async throws {
            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            await machine.waitFor(state: .background)
            await machine.testTransition(to: .bbb, failsWith: .suspended)
        }
    }
#endif
