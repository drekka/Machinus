//
//  File.swift
//
//
//  Created by Derek Clarkson on 3/12/2022.
//

import Foundation

#if os(macOS)
    /// Defines MacOS unique features.
    struct MacOSPlatform<S>: Platform where S: StateIdentifier {

        func configure(machine: any Machine<S>, executor: isolated any TransitionExecutor<S>) async throws {}
    }
#endif
