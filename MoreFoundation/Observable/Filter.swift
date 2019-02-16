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

private class Filter<T>: ObservableType<T> {

    private let source: ObservableType<T>
    private let isIncluded: (T) -> Bool

    fileprivate init(source: ObservableType<T>, isIncluded: @escaping (T) -> Bool) {
        self.source = source
        self.isIncluded = isIncluded
    }

    override fileprivate func subscribe(_ observer: Observer<T>) -> Disposable {
        return source.subscribe { event in
            if case let .next(value) = event, !self.isIncluded(value) {
            } else {
                observer.on(event)
            }
        }
    }
}

public extension ObservableType {

    /// Filter some `.next` events
    ///
    /// - Parameter isIncluded: function called to check if `.next` data must be included
    /// - Returns: a new observable
    func filter(_ isIncluded: @escaping (T) -> Bool) -> ObservableType<T> {
        return Filter(source: self, isIncluded: isIncluded)
    }
}
