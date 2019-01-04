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

/// A result that can be a value or an error
public enum Result<Value> {
    /// result is a value
    case value(Value)
    /// result is an error
    case error(Error)

    /// Get the result value
    ///
    /// - Returns: result value
    /// - Throws: error if result is an error
    public func get() throws -> Value {
        switch self {
        case .value(let val):
            return val
        case .error(let err):
            throw err
        }
    }
}

/// A future value
public class Future<Value> {
    /// Result, when future is completed
    private var result: Result<Value>?
    /// List of waiters
    private var awaiters = [(DispatchQueue?, (Result<Value>) -> Void)]()
    /// lock
    private let lockQueue = DispatchQueue(label: "MoreFoundation.Future")
    /// Block to call to cancel the function generating the Future
    fileprivate var cancelBlock: (() -> Void)?
    /// Parent future, when chained with `then`
    fileprivate var parentCancel: (() -> Void)?
    /// True if future as been cancelled
    public private(set) var cancelled = false

    /// Call completion block when the Future has completed
    ///
    /// - Parameters:
    ///   - queue: queue to call the completion block on, nil to call it on the default async function thread
    ///   - completionBlock: completion block
    ///   - result: completed Future result
    public func await(on queue: DispatchQueue? = nil, completionBlock: @escaping (_ result: Result<Value>) -> Void) {
        if !cancelled {
            lockQueue.sync {
                awaiters.append((queue, completionBlock))
            }
            if let result = result {
                report(result)
            }
        }
    }

    /// Call completion block when the Future has completed successfully
    ///
    /// - Parameters:
    ///   - queue: queue to call the completion block on, nil to call it on the default async function thread
    ///   - completionBlock: completion block
    ///   - result: completed Future result
    @discardableResult
    public func done(on queue: DispatchQueue? = nil, completionBlock: @escaping (Value) -> Void) -> Future<Value> {
        await(on: queue) { result in
            if case let .value(value) = result {
                completionBlock(value)
            }
        }
        return self
    }

    /// Call completion block when the Future has completed with an error
    ///
    /// - Parameters:
    ///   - queue: queue to call the completion block on, nil to call it on the default async function thread
    ///   - completionBlock: completion block
    ///   - result: completed Future error
    @discardableResult
    public func `catch`(on queue: DispatchQueue? = nil, completionBlock: @escaping (Error) -> Void) -> Future<Value> {
        await(on: queue) { result in
            if case let .error(error) = result {
                completionBlock(error)
            }
        }
        return self
    }

    /// Call completion block when the Future has completed
    ///
    /// - Parameters:
    ///   - queue: queue to call the completion block on, nil to call it on the default async function thread
    ///   - completionBlock: completion block
    public func finally(on queue: DispatchQueue? = nil, completionBlock: @escaping () -> Void) {
        await(on: queue) { _ in
            completionBlock()
        }
    }

    /// Cancel the Future
    public func cancel() {
        cancelled = true
        if result == nil {
            cancelBlock?()
        }
        parentCancel?()
    }

    /// Call a new async function when the future has completed successfully
    ///
    /// - Parameters:
    ///   - queue: queue to call the completion block on, nil to call it on the default async function thread
    ///   - block: block to call when the future has completed
    /// - Returns: new Future
    public func then<U>(on queue: DispatchQueue? = nil,
                        _ block: @escaping (_ promise: Promise<U>, _ value: Value) throws -> Void) -> Future<U> {
        let promise = Promise<U>()
        promise.parentCancel = cancel
        await(on: queue) { result in
            switch result {
            case .value(let value):
                do {
                    try block(promise, value)
                } catch {
                    promise.reject(with: error)
                }
            case .error(let error):
                promise.reject(with: error)
            }
        }
        return promise
    }

    /// Complete the future
    ///
    /// - Parameter value: result
    fileprivate func complete(with value: Result<Value>) {
        if result == nil {
            result = value
            report(value)
        }
    }

    /// Notify waiters the future has completed
    ///
    /// - Parameter result: future result
    private func report(_ result: Result<Value>) {
        var awaiters = [(DispatchQueue?, (Result<Value>) -> Void)]()
        lockQueue.sync {
            awaiters = self.awaiters
            self.awaiters.removeAll()
        }
        awaiters.forEach { queue, completionBlock in
            if let queue = queue {
                queue.async { completionBlock(result) }
            } else {
                completionBlock(result)
            }
        }
    }
}

/// A promise value
public class Promise<Value>: Future<Value> {

    public override init() {
    }

    /// Fulfill the promise with a value
    ///
    /// - Parameter value: promise value
    public func fulfill(with value: Value) {
        complete(with: .value(value))
    }

    /// Reject the promise with an error
    ///
    /// - Parameter error: promise error
    public func reject(with error: Error) {
        complete(with: .error(error))
    }

    /// Register the bloc to call when the future is cancelled
    ///
    /// - Parameter cancelBlock: bloc to call when the future is cancelled
    public func registerCancel(_ cancelBlock: @escaping () -> Void) {
        self.cancelBlock = cancelBlock
    }
}

/// Helper to call an async block
///
/// - Parameters:
///   - block: async block
///   - promise: promise passed to the async block
/// - Returns: future
public func async<T>(block: (_ promise: Promise<T>) -> Void) -> Future<T> {
    let promise = Promise<T>()
    block(promise)
    return promise
}
