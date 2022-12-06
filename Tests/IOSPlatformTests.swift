//
//  Created by Derek Clarkson on 23/11/2022.
//

import Foundation
@testable import Machinus
import Nimble
import XCTest

#if os(iOS) || os(tvOS)
    class IOSPlatformTests: XCTestCase {

        private var log: [String]!
        override func setUp() {
            super.setUp()
            log = []
        }

        func testInitWithMultipleBackgroundStatesFails() async throws {
            do {
                _ = try await StateMachine {
                    StateConfig<MyState>(.aaa)
                    StateConfig<MyState>.background(.background) // Background state 1
                    StateConfig<MyState>.background(.ccc) // Background state 2
                }
            } catch StateMachineError<MyState>.configurationError(let message) {
                expect(message) == "Multiple background states detected. Only one is allowed."
            }
        }

        func testMachineGoesIntoBackground() async throws {

            let machine = try await StateMachine {
                StateConfig<MyState>(.aaa, didExit: { _, _ in self.log.append("aaaExit") }) // Should not be called.
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>.background(.background, didEnter: { _, _ in self.log.append("backgroundEnter") })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            expectMachine(machine, toEventuallyHaveState: .background)
            expect(self.log) == ["backgroundEnter"]
        }

        func testMachineReturnsToForeground() async throws {

            let machine = try await StateMachine {
                StateConfig<MyState>(.aaa, didEnter: { _, _ in self.log.append("aaaEnter") }) // Should not be called
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>.background(.background, didExit: { _, _ in self.log.append("backgroundExit") })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            expectMachine(machine, toEventuallyHaveState: .background)

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            expectMachine(machine, toEventuallyHaveState: .aaa)

            expect(self.log) == ["backgroundExit"]
        }

        func testMachineReturnsToForegroundThenRedirects() async throws {

            let machine = try await StateMachine {
                StateConfig<MyState>(.aaa, didEnter: { _, _ in self.log.append("aaaEnter") }, transitionBarrier: { _ in .redirect(to: .bbb) }) // Should not be called
                StateConfig<MyState>(.bbb, didEnter: { _, _ in self.log.append("bbbEnter") }) // Also should not be called.
                StateConfig<MyState>.background(.background, didExit: { _, _ in
                    self.log.append("backgroundExit")
                    
                })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            expectMachine(machine, toEventuallyHaveState: .background)

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)
            expectMachine(machine, toEventuallyHaveState: .bbb)

            expect(self.log) == ["backgroundExit"]
        }
    }
#endif
