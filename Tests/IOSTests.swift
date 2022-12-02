//
//  Created by Derek Clarkson on 23/11/2022.
//

import Foundation
@testable import Machinus
import Nimble
import XCTest

#if os(iOS) || os(tvOS)
    class IOSTests: XCTestCase {

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
            } catch StateMachineError.configurationError(let message) {
                expect(message) == "Multiple background states detected. Only one is allowed."
            }
        }

        func testMachineGoesIntoBackground() async throws {

            let machine = try await StateMachine {
                StateConfig<MyState>(.aaa, didExit: { _ in self.log.append("aaaExit") }) // Should not be called.
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>.background(.background, didEnter: { _ in self.log.append("backgroundEnter") })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            await expect(machine.state).toEventually(equal(.background))

            expect(self.log) == ["backgroundEnter"]
        }

        func testMachineReturnsToForeground() async throws {

            let machine = try await StateMachine {
                StateConfig<MyState>(.aaa, didEnter: { _ in self.log.append("aaaEnter") }) // Should not be called
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>.background(.background, didExit: { _ in self.log.append("backgroundExit") })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            await expect(machine.state).toEventually(equal(.background))

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            await expect(machine.state).toEventually(equal(.aaa))

            expect(self.log) == ["backgroundExit"]
        }

        func testMachineReturnsToForegroundThenRedirects() async throws {

            let machine = try await StateMachine {
                StateConfig<MyState>(.aaa, didEnter: { _ in self.log.append("aaaEnter") }, transitionBarrier: { .redirect(to: .bbb) }) // Should not be called
                StateConfig<MyState>(.bbb, didEnter: { _ in self.log.append("bbbEnter") }) // Also should not be called.
                StateConfig<MyState>.background(.background, didExit: { _ in
                    self.log.append("backgroundExit")
                    
                })
            }

            await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            await expect(machine.state).toEventually(equal(.background))

            await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)
            await expect(machine.state).toEventually(equal(.bbb))

            expect(self.log) == ["backgroundExit"]
        }
    }
#endif
