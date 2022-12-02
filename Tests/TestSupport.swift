//
//  Created by Derek Clarkson on 23/11/2022.
//

import Foundation
import Machinus
import Nimble
import XCTest

enum MyState: StateIdentifier {
    case aaa
    case bbb
    case ccc
    case background
    case final
    case global
}

extension StateMachineError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {

        case (.transitionDenied, .transitionDenied),
             (.alreadyInState, .alreadyInState),
             (.illegalTransition, .illegalTransition):
            return true

        case (.noDynamicClosure(let lhsState as MyState), .noDynamicClosure(let rhsState as MyState)),
             (.unknownState(let lhsState as MyState), .unknownState(let rhsState as MyState)):
            return lhsState == rhsState

        default:
            return false
        }
    }
}
