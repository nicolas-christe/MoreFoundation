/// Copyright (c) 2018 Nicolas Christe
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

public class EventStore<T> {

    enum Error: Swift.Error {
        case empty
        case wrongEventType
   }
    public private(set) var latestEvents = [Event<T>]()

    private let disposeBag = DisposeBag()

    public init(source: Observable<T>) {
        source.subscribe { self.latestEvents.append($0) }.disposed(by: disposeBag)
    }

    public func clear() {
        latestEvents = []
    }

    public func pop() throws -> Event<T> {
        guard !latestEvents.isEmpty else {
            throw Error.empty
        }
        return latestEvents.removeFirst()
    }

    public func popValue() throws -> T {
        guard !latestEvents.isEmpty else {
            throw Error.empty
        }
        guard case let .next(value) = latestEvents.removeFirst() else {
            throw Error.wrongEventType
        }
        return value
    }

    public func popTerminated() throws {
        guard !latestEvents.isEmpty else {
            throw Error.empty
        }
        guard case .terminated = latestEvents.removeFirst() else {
            throw Error.wrongEventType
        }
    }

    public func peek() -> Event<T>? {
        return latestEvents.first
    }
}

public extension Observable {
    public func subscribeStore() -> EventStore<T> {
        return EventStore(source: self)
    }
}
