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

private class Map<T, U>: Observable<U> {

    private let source: Observable<T>
    private let disposeBag = DisposeBag()
    private let transform: (T) -> U

    init(source: Observable<T>, transform: @escaping (T) -> U) {
        self.source = source
        self.transform = transform
    }

    public override func subscribe<O: ObserverType> (_ observer: O) -> Disposable where O.EventType == Event<U> {
        super.subscribe(observer).disposed(by: disposeBag)
        return source.subscribe { event in
            switch event {
            case .value(let value):
                self.on(.value(self.transform(value)))
            }
        }
    }
}

public extension Observable {
    public func map<U>(_ transform: @escaping (T) -> U) -> Observable<U> {
        return Map(source: self, transform: transform)
    }
}