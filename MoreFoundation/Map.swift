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

    private weak var source: Observable<T>?
    private let disposeBag = DisposeBag()
    private let transform: (T) -> U

    init(source: Observable<T>, transform: @escaping (T) -> U) {
        self.source = source
        self.transform = transform
    }

    override func subscribe(_ observer: Observer<U>) -> Disposable {
        let disposable = super.subscribe(observer)
        if let source = source {
            source.subscribe { event in
                switch event {
                case .next(let value):
                    self.on(.next(self.transform(value)))
                case .terminated:
                    self.disposeBag.dispose()
                }
            }.disposed(by: disposeBag)
        } else {
            self.on(.terminated)
        }
        return disposable
    }
}

public extension Observable {
    public func map<U>(_ transform: @escaping (T) -> U) -> Observable<U> {
        return Map(source: self, transform: transform)
    }
}
