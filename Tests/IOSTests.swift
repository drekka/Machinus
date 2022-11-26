//
//  File.swift
//
//
//  Created by Derek Clarkson on 23/11/2022.
//

import Foundation
@testable import Machinus
import Nimble
import XCTest

#if os(iOS) || os(tvOS)
    class IOSTests: XCTestCase {

        func testInitWithMultipleBackgroundStatesGeneratesFatal() {
            expect(_ = StateMachine {
                StateConfig<MyState>(.aaa)
                StateConfig<MyState>.background(.background)
                StateConfig<MyState>.background(.ccc)
            }).to(throwAssertion())
        }

        func testMachineGoesIntoBackground() {

            var aaaExit = false
            var backgroundEnter = false

            let machine = StateMachine {
                StateConfig<MyState>(.aaa, didExit: { _ in aaaExit = true })
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>.background(.background, didEnter: { _ in backgroundEnter = true })
            }

            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            expect(machine.state).toEventually(equal(.background))

            expect(aaaExit) == false
            expect(backgroundEnter) == true
        }

        func testMachineReturnsToForeground() {

            var aaaEnter = false
            var backgroundExit = false

            let machine = StateMachine {
                StateConfig<MyState>(.aaa, didEnter: { _ in aaaEnter = true })
                StateConfig<MyState>(.bbb)
                StateConfig<MyState>.background(.background, didExit: { _ in backgroundExit = true })
            }

            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)

            expect(machine.state).toEventually(equal(.background))

            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

            expect(machine.state).toEventually(equal(.aaa))

            expect(backgroundExit) == true
            expect(aaaEnter) == false
        }

        func testMachineReturnsToForegroundWithRedirect() {

            var aaaEnter = false
            var bbbEnter = false
            var backgroundExit = false

            let machine = StateMachine {
                StateConfig<MyState>(.aaa, didEnter: { _ in aaaEnter = true }, transitionBarrier: { .redirect(to: .bbb) })
                StateConfig<MyState>(.bbb, didEnter: { _ in bbbEnter = true })
                StateConfig<MyState>.background(.background, didExit: { _ in backgroundExit = true })
            }

            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
            expect(machine.state).toEventually(equal(.background))

            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)
            expect(machine.state).toEventually(equal(.bbb))

            expect(backgroundExit) == true
            expect(aaaEnter) == false
            expect(bbbEnter) == false
        }
    }
#endif
