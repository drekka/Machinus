//
//  Created by Derek Clarkson on 2/12/2022.
//

import Foundation
import Combine

/// A "Missing" implementation that allows us to generate a throwing sequence from a publisher.
public struct AsyncThrowingSequence<T, E>: AsyncSequence where E: Error {

    public typealias AsyncIterator = AsyncThrowingPublisher<AnyPublisher<T, E>>.Iterator
    public typealias Element = T

    private let publisher: AsyncThrowingPublisher<AnyPublisher<T, E>>

    public init<P>(publisher: P) where P: Publisher, P.Output == T, P.Failure == E {
        let anyPublisher = publisher as? AnyPublisher<T, E> ?? publisher.eraseToAnyPublisher()
        self.publisher = AsyncThrowingPublisher(anyPublisher)
    }

    public func makeAsyncIterator() -> AsyncIterator {
        publisher.makeAsyncIterator()
    }
}
