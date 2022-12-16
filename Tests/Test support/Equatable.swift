//
//  Created by Derek Clarkson on 9/12/2022.
//

import Foundation
@testable import Machinus

extension StateMachineError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {

        case (.transitionDenied, .transitionDenied),
             (.alreadyInState, .alreadyInState),
             (.suspended, .suspended),
             (.illegalTransition, .illegalTransition):
            return true

        case (.noDynamicClosure(let lhsState as TestState), .noDynamicClosure(let rhsState as TestState)),
             (.unknownState(let lhsState as TestState), .unknownState(let rhsState as TestState)):
            return lhsState == rhsState

        default:
            return false
        }
    }
}

extension StateConfig<TestState>.PreflightResponse<TestState>: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.allow, .allow):
            return true
        case (.redirect(let lhsState), .redirect(let rhsState)):
            return lhsState == rhsState
        default:
            return false
        }
    }
}
