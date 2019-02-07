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

public protocol Bindable {
}

/// Observed events handler
public enum BindableEventHandler<O, T> {
    /// All events handler
    case onEvent((O, Event<T>) -> Void)
    /// Handler of .next events
    case onNext((O, T) -> Void)
    /// Handler of .terminated events
    case onTerminated((O) -> Void)
}

// MARK: - Extension for AnyObject
public extension Bindable where Self: AnyObject {

    func bind<T>(to observable: ObservableType<T>, _ handler: BindableEventHandler<Self, T>) -> Disposable {
        switch handler {
        case .onEvent(let handler):
            return observable.subscribe(.onEvent { [weak self] event in
                if let `self` = self {
                    handler(self, event)
               }
            })
        case .onNext(let handler):
            return observable.subscribe(.onNext { [weak self] value in
                if let `self` = self {
                    handler(self, value)
                }
            })
        case .onTerminated(let handler):
            return observable.subscribe(.onTerminated { [weak self] in
                if let `self` = self {
                    handler(self)
                }
            })
        }
    }
}

// MARK: - Add bind common types
extension NSObject: Bindable {
}
