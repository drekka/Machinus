//
//  File.swift
//
//
//  Created by Derek Clarkson on 11/12/2022.
//

import Combine
import Foundation
@testable import Machinus
import Nimble
import os
import XCTest

/// Required to ensure that the `Cancellable` returned by the `.sink(...)` get's cancelled. Otherwise the sink will continue to respond to state changes beyond the scope of the wait.
actor CancellableActor {
    var cancellable: AnyCancellable?
    func setCancellable(_ value: AnyCancellable?) {
        if value == nil {
            cancellable?.cancel()
        }
        cancellable = value
    }
}

/// Waits for a machine reaches a specified state, or times out.
///
/// - parameters:
///   - seconds: The number of seconds before timing out. May be fractional.
///   - expectedState: The desired state.
extension Transitionable {

    func waitFor(file: StaticString = #file, line: UInt = #line,
                 for seconds: Double = 5.0,
                 state expectedState: S) async {

        let cancellableActor = CancellableActor()

        // Wait until the engine enters the state or we time out.
        await withCheckedContinuation { success in

            // Setup a task to watch for the desired state.
            Task {
                await cancellableActor.setCancellable(self.statePublisher.sink { newState in
                    if newState == expectedState {
                        success.resume()
                    }
                })
            }

            // Setup a second task with a timer to timeout if the state is not reached.
            // Note that I tried a ``Timer`` here but it never fired no matter what I did. Even if it
            // was on a background thread.
            Task.detached(priority: .background) { [weak self] in
                try? await Task.sleep(for: .milliseconds(seconds * 1000))
                guard let self else { return }
                fail("Timed out waiting \(seconds) for state .\(expectedState), machine current state \(await self.currentState)", file: file, line: line)
                success.resume()
            }
        }

        // Ensure all cancellables are killed off. This also ensures we don't double resume the checked wait.
        await cancellableActor.setCancellable(nil)
    }
}
