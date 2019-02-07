/// Copyright (c) 2019 Nicolas Christe
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

import Foundation

public protocol OptionalType {
    associatedtype WrappedType
    var asOptional: WrappedType? { get }
}

extension Optional: OptionalType {
    public var asOptional: Wrapped? {
        return self
    }
}

/// Convert from an Observeable with no nil `Event<T>` to and Observeable with `Event<U>`
private class CompactMap<T, U>: ObservableType<U> where T: OptionalType {

    /// Source observable
    private let source: ObservableType<T>
    /// `T` to `U` transform closure
    private let transform: (T.WrappedType) -> U

    /// Constructor
    ///
    /// - Parameters:
    ///   - source: source observable
    ///   - transform: `T` to `U` transform closure
    public init(source: ObservableType<T>, transform: @escaping (T.WrappedType) -> U) {
        self.source = source
        self.transform = transform
    }

    override func subscribe(_ observer: Observer<U>) -> Disposable {
        return source.subscribe { event in
            switch event {
            case .next(let value):
                if let value = value.asOptional {
                    observer.on(.next(self.transform(value)))
                }
            case .terminated:
                observer.on(.terminated)
            }
        }
    }
}

public extension ObservableType where T: OptionalType {

    /// Convert from an `Event` data type to `U`
    ///
    /// - Parameters:
    ///     - transform: closure called to transform `T` to `U`
    ///     - eventData: source event data
    /// - Returns: a new observable
    func compactMap<U>(_ transform: @escaping (_ eventData: T.WrappedType) -> U)  -> ObservableType<U> {
            return CompactMap(source: self, transform: transform)
    }

    func compactMap() -> ObservableType<T.WrappedType> {
        return CompactMap(source: self, transform: {$0})
    }
}
