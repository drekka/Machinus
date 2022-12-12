//
//  Created by Derek Clarkson on 2/12/2022.
//

import Foundation
import Combine

/// Version of an ``AsyncPublisher`` that erases the wrapped publisher.
public struct ErasedAsyncPublisher<T>: AsyncSequence {

    public typealias AsyncIterator = AsyncPublisher<AnyPublisher<T, Never>>.Iterator
    public typealias Element = T

    private let publisher: AsyncPublisher<AnyPublisher<T, Never>>

    public init<P>(publisher: P) where P: Publisher, P.Output == T, P.Failure == Never {
        let anyPublisher = publisher as? AnyPublisher<T, Never> ?? publisher.eraseToAnyPublisher()
        self.publisher = AsyncPublisher(anyPublisher)
    }

    public func makeAsyncIterator() -> AsyncIterator {
        publisher.makeAsyncIterator()
    }
}
