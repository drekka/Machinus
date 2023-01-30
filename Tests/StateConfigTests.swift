//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

@testable import Machinus
import Nimble
import XCTest

class StateConfigTests: XCTestCase {

    private var stateA: StateConfig<TestState> = StateConfig(.aaa)
    private var stateAA: StateConfig<TestState> = StateConfig(.aaa)
    private var stateB: StateConfig<TestState> = StateConfig(.bbb)

    // MARK: - Custom debug string convertable

    func testCustomStringConvertable() {
        expect(self.stateA.description) == ".aaa"
        expect(self.stateB.description) == ".bbb"
    }

    // MARK: - Equatable

    func testEquatableConfigEqualsConfig() {
        expect(self.stateA == self.stateAA) == true
        expect(self.stateA == self.stateB) == false
    }

    // MARK: - State storage

    func testStorageStoringValues() {
        stateA.abc = "abc"
        stateA.def = 5

        expect(self.stateA.abc) == "abc"
        expect(self.stateA.def) == 5
    }

    func testStorageClearingValues() {
        stateA["abc", true] = "abc"
        stateA.def = 5

        expect(self.stateA.abc) == "abc"
        expect(self.stateA.def) == 5

        stateA.clearStore()

        expect(self.stateA.abc) == "abc"
        expect(self.stateA.def as String?).to(beNil())
    }


}
