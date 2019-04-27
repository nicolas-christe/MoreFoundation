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

/// Define a class that can be store in a `DisposeBag`
public protocol Disposable: AnyObject {
    func disposed(by disposeBag: DisposeBag)
}

extension Disposable {
    /// Put a disposable on a dispose bag
    ///
    /// - Parameter disposeBag: disposable to put in the dispose bag
    public func disposed(by disposeBag: DisposeBag) {
        disposeBag.add(disposable: self)
    }
}

/// Hold strong references on `Disposable` object
public class DisposeBag: Disposable {

    /// List of disposable in the bag
    private var disposables = [Disposable]()

    public init() {
    }

    /// Add a disposable into the bag
    ///
    /// - Parameter disposable: disposable to add
    fileprivate func add(disposable: Disposable) {
        disposables.append(disposable)
    }

    /// Dispose all disposable in the bag
    public func dispose() {
        disposables.removeAll()
    }
}
