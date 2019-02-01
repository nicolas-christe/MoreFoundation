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

/// An observable event
public enum Event<T> {
    /// Observable provided a next value
    case next(T)
    /// Observable did terminates
    case terminated

    /// `.next` event value, nil if event is not `.next`
    public var value: T? {
        if case let .next(value) = self {
            return value
        }
        return nil
    }
}

// Event are Equatable if value type is Equatable
extension Event: Equatable where T: Equatable {
}

/// Base observable type
public class ObservableType<T> {

    /// True if the observable is terminated and will not produce more events.
    public private(set) var terminated = false

    /// Subscribe to observable events.
    ///
    /// - Parameter observer: observer to subscribe.
    /// - Returns: Disposable. Observer is subscribed until this disposable is deleted.
    func subscribe(_ observer: Observer<T>) -> Disposable {
        fatal("Must be overriden")
    }

    /// Send `.next` event to all observers.
    ///
    /// - Parameter value: next value.
    public func onNext(_ value: T) {
        guard !terminated else {
            fatal("onNext called on a terminated observable")
        }
        self.on(.next(value))
    }

    /// Send `.terminated` event to all observers.
    public func onTerminated() {
        guard !terminated else { return }
        terminated = true
        self.on(.terminated)
    }

    /// Process events.
    ///
    /// - Parameter event: event to send to observers.
    fileprivate func on(_ event: Event<T>) {
        fatal("Must be overriden")
    }
}

/// An observer
public class Observer<T> {

    /// Observed events handler
    public enum EventHandler {
        /// All events handler
        case onEvent((Event<T>) -> Void)
        /// Handler of .next events
        case onNext((T) -> Void)
        /// Handler of .terminated events
        case onTerminated(() -> Void)
    }

    /// register handlers
    private let handlers: [EventHandler]

    /// Constructor
    ///
    /// - Parameter handlers: events handlers
    public init(_ handlers: [EventHandler]) {
        self.handlers = handlers
    }

    /// Constructor
    ///
    /// - Parameter handlers: events handlers
    public convenience init(_ handlers: EventHandler...) {
        self.init(handlers)
    }

    /// Process event
    ///
    /// - Parameter event: event to process
    func on(_ event: Event<T>) {
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

// Add convenience subscribe
public extension ObservableType {

    func subscribe(_ handlers: Observer<T>.EventHandler...) -> Disposable {
        return subscribe(Observer(handlers))
    }

    func subscribe(_ eventHandler: @escaping (Event<T>) -> Void) -> Disposable {
        return subscribe(Observer(.onEvent(eventHandler)))
    }
}

/// An Observable that generate a sequence of `Event<T>`.
public class Observable<T>: ObservableType<T> {

    /// Callback called when the first observer is about to subscribe.
    private let willBeObservedCb: () -> Void
    /// Callback called when the last observer did unsubscribe.
    private let wasObservedCb: () -> Void

    /// Map of observers.
    private var observers = [ObjectIdentifier: Observer<T>]()

    public init(willBeObserved: @escaping () -> Void = {}, wasObserved: @escaping () -> Void = {}) {
        self.willBeObservedCb = willBeObserved
        self.wasObservedCb = wasObserved
    }

    deinit {
        onTerminated()
    }

    /// Subscribe to observable events.
    ///
    /// - Parameter observer: observer to subscribe.
    /// - Returns: Disposable. Observer is subscribed until this disposable is deleted.
    public override func subscribe(_ observer: Observer<T>) -> Disposable {
        if observers.isEmpty {
            willBeObserved()
        }
        let identifier = ObjectIdentifier(observer)
        observers[identifier] = observer
        if terminated {
            observer.on(.terminated)
        }
        return Registration(observable: self, identifier: identifier)
    }

    /// Process events.
    ///
    /// - Parameter event: event to send to observers.
    override func on(_ event: Event<T>) {
        observers.values.forEach {
            $0.on(event)
        }
    }

    /// Called when the first observer is about to subscribe
    private func willBeObserved() {
        self.willBeObservedCb()
    }

    /// Called when the last observer did unsubscribe
    private func wasObserved() {
        self.wasObservedCb()
    }

    /// Unsubsribe an observer
    ///
    /// - Parameter identifier: observer identifier.
    private func unsubscribe(_ identifier: ObjectIdentifier) {
        observers[identifier] = nil
        if observers.isEmpty {
            wasObserved()
        }
    }

    /// An observer registration
    private class Registration: Disposable {

        /// Observabe the observer registered to
        private weak var observable: Observable<T>?
        /// Observer identifier
        private let identifier: ObjectIdentifier

        /// Constructor
        ///
        /// - Parameters:
        ///   - observable: observable the observer registered to
        ///   - identifier: observer identifier
        init(observable: Observable<T>, identifier: ObjectIdentifier) {
            self.observable = observable
            self.identifier = identifier
        }

        deinit {
            observable?.unsubscribe(identifier)
        }
    }
}
