//
//  File.swift
//
//
//  Created by Derek Clarkson on 11/12/2022.
//

import Foundation
import Nimble

/// Waits until an assertion becomes true.
///
/// This polls the assertion using the passed `pollPeriod` interval using ``Task.sleep(...)``. it's al alternative to
/// the `XCTest` expectation API which seems to tie up Tasks even when they are operating on a different thread.
///
/// - parameters:
///   - seconds: The number of seconds before timing out. May be fractional.
///   - pollPeriod: How often (in milliseconds) to check the assertion.
///   - timeoutMessage: The message to display if the wait times out.
///   - assertion: The assertion to check. If this never returns `true` the wait will time out.
func waitFor(file: StaticString = #file, line: UInt = #line,
             for seconds: Double = 5.0,
             polling pollPeriod: Int = 50,
             timeoutMessage: String = "Timed out waiting for assertion to be true",
             _ assertion: @autoclosure () async -> Bool) async {
    let clock = ContinuousClock()
    let startedAt = clock.now
    // swiftformat:disable:next --redundantParens
    while !(await assertion()) {
        try? await Task.sleep(for: .milliseconds(pollPeriod))
        let components = startedAt.duration(to: clock.now).components
        let duration = Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        if duration > seconds {
            fail(timeoutMessage, file: file, line: line)
            break
        }
    }
}
