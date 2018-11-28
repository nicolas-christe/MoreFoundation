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

public class Observable<T> {

    private let willBeObserved: () -> Void
    private let wasObserved: () -> Void

    private var observers = [ObjectIdentifier: Observer<T>]()
    public private(set) var terminated = false

    public init(willBeObserved: @escaping () -> Void = {}, wasObserved: @escaping () -> Void = {}) {
        self.willBeObserved = willBeObserved
        self.wasObserved = wasObserved
    }

    deinit {
        onTerminated()
    }

    public func subscribe(_ observer: Observer<T>) -> Disposable {
        guard !terminated else {
            observer.on(.terminated)
            return DummyDisposable()
        }
        if observers.isEmpty {
            willBeObserved()
        }
        let identifier = ObjectIdentifier(observer)
        observers[identifier] = observer
        return Registration(observable: self, identifier: identifier)
    }

    public func onNext(_ value: T) {
        guard !terminated else {
            fatal("onNext called on a terminated observable")
        }
        self.on(.next(value))
    }

    public func onTerminated() {
        terminated = true
        self.on(.terminated)
        if observers.count > 0 {
            observers.removeAll()
            wasObserved()
        }
    }
    private func on(_ event: Event<T>) {
        observers.values.forEach {
            $0.on(event)
        }
    }

    private func unsubscribe(_ identifier: ObjectIdentifier) {
        observers[identifier] = nil
        if observers.isEmpty {
            wasObserved()
        }
    }

    public class Proxy<U>: Observable<U> {

        private weak var source: Observable<T>?
        private let disposeBag = DisposeBag()

        init(source: Observable<T>) {
            self.source = source
        }

        override public func subscribe(_ observer: Observer<U>) -> Disposable {
            let disposable = super.subscribe(observer)
            if let source = source {
                source.subscribe { event in
                    switch event {
                    case .next(let value):
                        self.process(next: value)
                    case .terminated:
                        self.disposeBag.dispose()
                    }
                    }.disposed(by: disposeBag)
            } else {
                self.onTerminated()
            }
            return disposable
        }

        func process(next: T) {
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

    private class DummyDisposable: Disposable {}
}

public class Observer<T> {

    public enum EventHandler {
        case onEvent((Event<T>) -> Void)
        case onNext((T) -> Void)
        case onTerminated(() -> Void)
    }

    private let handlers: [EventHandler]

    public init(_ handlers: [EventHandler]) {
        self.handlers = handlers
    }

    public convenience init(_ handlers: EventHandler...) {
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

    public func subscribe(_ handlers: Observer<T>.EventHandler...) -> Disposable {
        return subscribe(Observer(handlers))
    }

    public func subscribe(_ eventHandler: @escaping (Event<T>) -> Void) -> Disposable {
        return subscribe(Observer(.onEvent(eventHandler)))
    }
}
