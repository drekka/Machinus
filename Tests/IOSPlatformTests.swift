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
        private var machine: StateMachine<TestState>!

        override func setUp() async throws {

            try await super.setUp()

            log = []
            machine = StateMachine {
                StateConfig<TestState>(.aaa,
                                       didEnter: { _ in self.log.append("aaaEnter") },
                                       allowedTransitions: .bbb, .ccc,
                                       didExit: { _ in self.log.append("aaaExit") })
                StateConfig<TestState>(.bbb,
                                       didEnter: { _ in self.log.append("bbbEnter") },
                                       allowedTransitions: .ccc,
                                       didExit: { _ in self.log.append("bbbExit") })
                StateConfig<TestState>(.ccc,
                                       entryBarrier: { $0 == .aaa ? .allow : .redirect(to: .aaa) },
                                       didEnter: { _ in self.log.append("cccEnter") },
                                       allowedTransitions: .aaa,
                                       didExit: { _ in self.log.append("cccExit") })
                StateConfig<TestState>.background(.background,
                                                  didEnter: { _ in self.log.append("backgroundEnter") },
                                                  didExit: { _ in self.log.append("backgroundExit") })
            }
            didTransition: { from, to in
                self.log.append("\(from) -> \(to)")
            }
        }

        override func tearDown() {
            machine = nil
            super.tearDown()
        }

        func testMachineGoesIntoBackground() async {
            await machine.waitFor(publisher: machine.$state.eraseToAnyPublisher(), toProduce: .background) {
                Task {
                    await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
                }
            }
            expect(self.log) == ["backgroundEnter", "aaa -> background"]
        }

        func testMachineReturnsToForeground() async {

            await machine.waitFor(publisher: machine.$state.eraseToAnyPublisher(), toProduce: .background) {
                Task {
                    await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
                }
            }
            expect(self.log) == ["backgroundEnter", "aaa -> background"]

            await machine.waitFor(publisher: machine.$state.eraseToAnyPublisher(), toProduce: .aaa) {
                Task {
                    await NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)
                }
            }
            expect(self.log) == ["backgroundEnter", "aaa -> background", "backgroundExit", "background -> aaa"]
        }

        func testSuspendedMachineThrows() async {
            await machine.waitFor(publisher: machine.$state.eraseToAnyPublisher(), toProduce: .background) {
                Task {
                    await NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: self)
                }
            }
            await machine.testTransition(to: .aaa, failsWith: .suspended)
        }
    }
#endif
