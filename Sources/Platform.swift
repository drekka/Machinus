//
//  Created by Derek Clarkson on 3/12/2022.
//

import Foundation

/// Defines the interface to the underlying platform the code is running on.
protocol Platform<S> {
    associatedtype S: StateIdentifier
    func configure(for machine: any Machine<S>) async throws
}
