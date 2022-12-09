//
//  Created by Derek Clarkson on 9/12/2022.
//

import Foundation

/// Defines a result builder that can be used on the state machines init.
@resultBuilder
public struct StateConfigBuilder<S> where S: StateIdentifier {
    public static func buildBlock(_ configs: StateConfig<S>...) -> [StateConfig<S>] { configs }
}

