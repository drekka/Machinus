//
//  File.swift
//
//
//  Created by Derek Clarkson on 3/12/2022.
//

import Foundation

/// Provides internal access to the machine for various platforms.
protocol Machine<S>: AnyActor {

    associatedtype S: StateIdentifier

    var name: String { get }
    var stateConfigs: [S: StateConfig<S>] { get }

    func transition(toState: StateConfig<S>, didExit: DidExit<S>?, didEnter: DidEnter<S>?) async -> StateConfig<S>
}

extension StateMachine: Machine {}
