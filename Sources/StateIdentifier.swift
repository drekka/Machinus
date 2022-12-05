//
//  Created by Derek Clarkson on 5/6/21.
//  Copyright © 2021 Derek Clarkson. All rights reserved.
//
import os

/**
 Adopt this protocol to define a state implementation.
 */
public protocol StateIdentifier: Hashable, Sendable {}

public extension StateIdentifier {

    /// Used during logging to inject a descriptive representation of the state.
    var loggingIdentifier: String {
        ".\(self)"
    }
}

extension StateConfig: CustomStringConvertible {

    public var description: String {
        identifier.loggingIdentifier
    }
}
