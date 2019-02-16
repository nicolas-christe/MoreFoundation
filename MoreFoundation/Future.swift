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

/// A future value
public class Future<Success, Failure: Error> {
    /// Result, when future is completed
    private var result: Result<Success, Failure>?
    /// List of waiters
    private var awaiters = [(DispatchQueue?, (Result<Success, Failure>) -> Void)]()
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
    public func await(on queue: DispatchQueue? = nil,
                      completionBlock: @escaping (_ result: Result<Success, Failure>) -> Void) {
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
    public func done(on queue: DispatchQueue? = nil,
                     completionBlock: @escaping (Success) -> Void) -> Future<Success, Failure> {
        await(on: queue) { result in
            if case let .success(value) = result {
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
    public func `catch`(on queue: DispatchQueue? = nil,
                        completionBlock: @escaping (Failure) -> Void) -> Future<Success, Failure> {
        await(on: queue) { result in
            if case let .failure(error) = result {
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
    ///   - errorMapper: block converting failure `F` to `Failure`
    ///   - block: block to call when the future has completed
    /// - Returns: new Future
    public func then<U, F: Error>(on queue: DispatchQueue? = nil,
                                  errorMapper: @escaping (Failure) -> F,
                                  _ block: @escaping (_ promise: Promise<U, F>, _ value: Success) -> Void)
        -> Future<U, F> {
            let promise = Promise<U, F>()
            promise.parentCancel = cancel
            await(on: queue) { result in
                switch result {
                case .success(let value):
                    block(promise, value)
                case .failure(let error):
                    promise.reject(with: errorMapper(error))
                }
            }
            return promise
    }

    /// Call a new async function when the future has completed successfully.
    ///
    /// Special case when the new future has the same `Failure` type than the current one
    ///
    /// - Parameters:
    ///   - queue: queue to call the completion block on, nil to call it on the default async function thread
    ///   - block: block to call when the future has completed
    /// - Returns: new Future
    public func then<U>(on queue: DispatchQueue? = nil,
                        _ block: @escaping (_ promise: Promise<U, Failure>, _ value: Success) -> Void)
        -> Future<U, Failure> {
            return then(errorMapper: { $0 }, block)
    }

    /// Complete the future
    ///
    /// - Parameter value: result
    fileprivate func complete(with value: Result<Success, Failure>) {
        if result == nil {
            result = value
            report(value)
        }
    }

    /// Notify waiters the future has completed
    ///
    /// - Parameter result: future result
    private func report(_ result: Result<Success, Failure>) {
        var awaiters = [(DispatchQueue?, (Result<Success, Failure>) -> Void)]()
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
public class Promise<Success, Failure: Error>: Future<Success, Failure> {

    override public init() {
    }

    /// Fulfill the promise with a value
    ///
    /// - Parameter value: promise value
    public func fulfill(with value: Success) {
        complete(with: .success(value))
    }

    /// Reject the promise with an error
    ///
    /// - Parameter error: promise error
    public func reject(with error: Failure) {
        complete(with: .failure(error))
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
public func async<Success, Failure: Error>(block: (_ promise: Promise<Success, Failure>) -> Void)
    -> Future<Success, Failure> {
        let promise = Promise<Success, Failure>()
        block(promise)
        return promise
}
