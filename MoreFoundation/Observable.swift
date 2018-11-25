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

public enum Event<T> {
    case next(T)
    case terminated
}

extension Event: Equatable where T: Equatable {
}

public enum EventHandler<T> {
    case onEvent((Event<T>) -> Void)
    case onNext((T) -> Void)
    case onTerminated(() -> Void)
}

public protocol ObserverType: AnyObject {
    associatedtype EventType
    func on(_ event: EventType)
}

public class Observable<T> {

    private var observers = [ObjectIdentifier: (Event<T>) -> Void]()

    private let willBeObserved: () -> Void
    private let wasObserved: () -> Void

    public init(willBeObserved: @escaping () -> Void = {}, wasObserved: @escaping () -> Void = {}) {
        self.willBeObserved = willBeObserved
        self.wasObserved = wasObserved
    }

    deinit {
        on(.terminated)
    }

    public func subscribe<O: ObserverType> (_ observer: O) -> Disposable where O.EventType == Event<T> {
        if observers.isEmpty {
            willBeObserved()
        }
        let identifier = ObjectIdentifier(observer)
        observers[identifier] = observer.on
        return Registration(observable: self, identifier: identifier)
    }

    public func on(_ event: Event<T>) {
        observers.values.forEach {
            $0(event)
        }
    }

    private func unsubscribe(_ identifier: ObjectIdentifier) {
        observers[identifier] = nil
        if observers.isEmpty {
            wasObserved()
        }
    }

    private class Registration: Disposable {

        private weak var observable: Observable<T>?
        private let identifier: ObjectIdentifier

        init(observable: Observable<T>, identifier: ObjectIdentifier) {
            self.observable = observable
            self.identifier = identifier
        }

        deinit {
            observable?.unsubscribe(identifier)
        }
    }
}

public class Observer<T>: ObserverType {

    private let handlers: [EventHandler<T>]

    public init(_ handlers: [EventHandler<T>]) {
        self.handlers = handlers
    }

    public convenience init(_ handlers: EventHandler<T>...) {
        self.init(handlers)
    }

    public func on(_ event: Event<T>) {
        handlers.forEach {
            switch ($0, event) {
            case let (.onEvent(eventHandler), _):
                eventHandler(event)
            case let (.onNext(valueHandler), .next(value)):
                valueHandler(value)
            case let (.onTerminated(terminatedHandler), .terminated):
                terminatedHandler()
            default: break
            }
        }
    }
}

public extension Observable {

    public func subscribe(_ handlers: EventHandler<T>...) -> Disposable {
        return subscribe(Observer(handlers))
    }

    public func subscribe(_ eventHandler: @escaping (Event<T>) -> Void) -> Disposable {
        return subscribe(Observer(.onEvent(eventHandler)))
    }
}
