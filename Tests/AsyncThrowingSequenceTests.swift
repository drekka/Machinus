//
//  Created by Derek Clarkson on 2/12/2022.
//

import Combine
import Foundation
import Machinus
import Nimble
import XCTest

// These tests confirm the various techniques for iterating over an ``AsyncStream`` that throws.

// Ultimately this is to test the in-house ``AsyncThrowingSequence`` which was written because the Apple types
// expose the wrapped Publisher in their iterator types.

// Note that due to the lack of a buffer in Combine's ``AsyncThrowingPublisher`` this code needs to ensure that
// values are not sent too fast or the tests won't work.
class AsyncThrowingSequenceTests: XCTestCase {

    var publisher: CurrentValueSubject<Int, StateMachineError<TestState>>!
    var log: [Int]!
    var x: Int!

    override func setUp() {
        super.setUp()
        publisher = CurrentValueSubject(0)
        log = []
        x = 0
    }

    // Test confirming functionality of values property. This exposes the underlying publisher.
    func testPublisherValues() async throws {

        for try await value in publisher.values {
            log.append(value)
            sendNext()
        }

        await expect(self.log).toEventually(equal([0, 1, 2, 3, 4]))
    }

    // Using a throwing publisher. This version exposes the underlying publisher.
    func testAsyncThrowingPublisher() async throws {

        for try await value in AsyncThrowingPublisher(publisher) {
            log.append(value)
            sendNext()
        }

        expect(self.log) == [0, 1, 2, 3, 4]
    }

    // This uses an in-house ``AsyncThrowingSequence`` which erases the underlying publisher.
//    func testAsyncThrowingSequence() async throws {
//
//        for try await value in AsyncThrowingSequence(publisher: publisher) {
//            log.append(value)
//            sendNext()
//        }
//
//        expect(self.log) == [0, 1, 2, 3, 4]
//    }
//
//    // This uses an in-house ``AsyncThrowingSequence`` which erases the underlying publisher.
//    func testAsyncThrowingSequenceFailure() async throws {
//
//        do {
//            for try await value in AsyncThrowingSequence(publisher: publisher) {
//                log.append(value)
//                sendNext(then: .failure(.alreadyInState))
//            }
//            fail("Error not thrown")
//        }
//        catch StateMachineError<TestState>.alreadyInState {
//            expect(self.log) == [0, 1, 2, 3, 4]
//        }
//        catch {
//            fail("Unexpected error \(error)")
//        }
//    }

    func sendNext(then: Subscribers.Completion<StateMachineError<TestState>> = .finished) {
        Task {
            x += 1
            if x == 5 {
                self.publisher.send(completion: then)
            } else {
                self.publisher.send(x)
            }
        }
    }
}
