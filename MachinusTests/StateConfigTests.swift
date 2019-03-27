//
//  StateTests.swift
//  MachinusTests
//
//  Created by Derek Clarkson on 11/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import XCTest
@testable import Machinus
import Nimble

class StateTests: XCTestCase {

    enum MyState: StateIdentifier {
        case aaa
        case bbb
    }

    private var stateA: StateConfig<MyState>!
    private var stateAA: StateConfig<MyState>!
    private var stateB: StateConfig<MyState>!

    override func setUp() {
        self.stateA = StateConfig(identifier: .aaa, allowedTransitions: .bbb)
        self.stateAA = StateConfig(identifier: .aaa)
        self.stateB = StateConfig(identifier: .bbb)
    }

    // MARK: - Hashable

    func testHashValue() {
        expect(self.stateA!.hashValue) == MyState.aaa.hashValue
    }

    func testEquatableStateStateEquatable() {
        expect(self.stateA == self.stateAA).to(beTrue())
        expect(self.stateA != self.stateB).to(beTrue())
    }

    func testEquatableStateIdentifier() {
        expect(self.stateA == MyState.aaa).to(beTrue())
        expect(self.stateA! != MyState.bbb).to(beTrue())
    }

    func testEquatableIentifierState() {
        expect(MyState.aaa == self.stateA).to(beTrue())
        expect(MyState.bbb != self.stateA!).to(beTrue())
    }

    // MARK: - State properties

    func testCanTransition() {
        expect(self.stateA.canTransition(toState: self.stateB)).to(beTrue())
        expect(self.stateAA.canTransition(toState: self.stateB)).to(beFalse())
    }

    func testCanTransitionHonoursGlobal() {
        stateA.makeGlobal()
        expect(self.stateB.canTransition(toState: self.stateA)).to(beTrue())
    }
}
