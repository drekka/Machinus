//
//  Created by Derek Clarkson on 1/12/2022.
//

import Foundation
@testable import Machinus
import Nimble
import XCTest

enum TestState: StateIdentifier {
    case xyz
}

class StateIdentifierTests: XCTestCase {

    func testDescription() {
        expect("\(TestState.xyz)") == "xyz"
        expect(TestState.xyz.loggingIndentifier) == ".xyz"
    }
}
