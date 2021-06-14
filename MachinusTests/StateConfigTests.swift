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

class StateConfigTests: XCTestCase {

    enum MyState: StateIdentifier {
        case aaa
        case bbb
        case global
        case final
        case background
    }

    private var stateA: StateConfig<MyState> = StateConfig(.aaa,                 canTransitionTo: .bbb)
    private var stateAA: StateConfig<MyState> = StateConfig(.aaa)
    private var stateB: StateConfig<MyState> = StateConfig(.bbb)
    private var global: GlobalStateConfig<MyState> = GlobalStateConfig(.global,                 canTransitionTo: .aaa)
    private var final: FinalStateConfig<MyState> = FinalStateConfig(.final)
    private var background: BackgroundStateConfig<MyState> = BackgroundStateConfig(.background)

    // MARK: - Hashable

    func testHashValue() {
        expect(self.stateA.hashValue) == MyState.aaa.hashValue
    }
    
    // MARK: - Custom debug string convertable
    
    func testCustomDebugStringConvertable() {
        expect(self.stateA.debugDescription) == "aaa"
        expect(self.stateAA.debugDescription) == "aaa"
        expect(self.stateB.debugDescription) == "bbb"
    }
    
    // MARK: - Equatable

    func testEquatableConfigEqualsConfig() {
        expect(self.stateA == self.stateAA) == true
        expect(self.stateA == self.stateB) == false
    }

    func testEquatableStateEqualsConfig() {
        expect(MyState.aaa == self.stateA) == true
        expect(MyState.bbb == self.stateA) == false
    }

    func testEquatableConfigEqualsState() {
        expect(self.stateA == MyState.aaa) == true
        expect(self.stateA == MyState.bbb) == false
    }

    func testEquatableStateNotEqualsConfig() {
        expect(MyState.aaa != self.stateA) == false
        expect(MyState.bbb != self.stateA) == true
    }

    func testEquatableConfigNotEqualsState() {
        expect(self.stateA != MyState.aaa) == false
        expect(self.stateA != MyState.bbb) == true
    }

    // MARK: - State properties

    func testCanTransition() {
        expect(self.stateA.canTransition(toState: self.stateB)) == true
        expect(self.stateAA.canTransition(toState: self.stateB)) == false
    }
}
