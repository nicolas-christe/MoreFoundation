/// Copyright (c) 2018-19 Nicolas Christe
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

import XCTest
import MoreFoundation
import Hamcrest

private enum Error: Swift.Error {
    case fail
}

/// An async fun
///
/// - Parameters:
///   - promise: promise to complete asynchronous
///   - val: value to fulfil the promise with. If nil the promise is rejected with Error.fail.
private func asyncFunc(promise: Promise<String, Error>, val: String?) {
    DispatchQueue.main.async {
        if let val = val {
            promise.fulfill(with: val)
        } else {
            promise.reject(with: Error.fail)
        }
    }
}

class FutureTests: XCTestCase {

    /// Test `await`
    func testAwait() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.await { result in
                assertThat(try? result.get(), presentAnd(`is`("X")))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test calling `await` on a future that has already completed.
    func testAwaitAlreadyCompleted() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { (promise: Promise<String, Error>) in
            promise.fulfill(with: "X")
            }.await { result in
                assertThat(try? result.get(), presentAnd(`is`("X")))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test `done` is called when the future is fulfilled
    func testDone() {
        let expectation = XCTestExpectation(description: "Done called")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.done { str in
                assertThat(str, `is`("X"))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test `catch` is called when the future is rejected
    func testCatch() {
        let expectation = XCTestExpectation(description: "Catch called")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.catch { error in
                assertThat(error, `is`(Error.fail))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test `finally` is called
    func testFinally() {
        let expectation = XCTestExpectation(description: "Finally called")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.finally {
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // Test that `finally` is called after `done`
    func testDoneFinally() {
        let expectation1 = XCTestExpectation(description: "Done Called")
        let expectation2 = XCTestExpectation(description: "finally called")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.done { str in
                assertThat(str, `is`("X"))
                expectation1.fulfill()
            }.finally {
                expectation2.fulfill()
        }
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    // Test that `finally` is called after `catch`
    func testCatchFinally() {
        let expectation1 = XCTestExpectation(description: "Catch Called")
        let expectation2 = XCTestExpectation(description: "finally called")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.catch { error in
                assertThat(error, `is`(Error.fail))
                expectation1.fulfill()
            }.finally {
                expectation2.fulfill()
        }
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    /// Test `then`
    func testThen() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.then { promise, value in
                asyncFunc(promise: promise, val: value + "Y")
            }.done { str in
                assertThat(str, `is`("XY"))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test `then` when the first future is rejected, expect `catch` to be called
    func testThen1stFail() {
        let expectation = XCTestExpectation(description: "catch called")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.then { promise, value in
                asyncFunc(promise: promise, val: value + "Y")
            }.catch { error in
                assertThat(error, `is`(Error.fail))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test `then` when the 2nd future is rejected, expect `catch` to be called
    func testThen2ndFail() {
        let expectation = XCTestExpectation(description: "catch called")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.then { promise, _ in
                asyncFunc(promise: promise, val: nil)
            }.catch { error in
                assertThat(error, `is`(Error.fail))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMap() {
        let expectation = XCTestExpectation(description: "catch called")
        var cnt: Int?
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.map {
                cnt = $0.count
            }.finally {
                assertThat(cnt, presentAnd(`is` (1)))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// test cancelling 2 chained feature, when `cancel` is called while the 1st future is pending
    func testCancel1st() {
        var cancel1Called = false
        var cancel2Called = false
        async { promise in
            promise.registerCancel({ cancel1Called = true })
            }.then { (promise: Promise<Void, Error>, _: Void) in
                promise.registerCancel({ cancel2Called = true })
            }.cancel()
        assertThat(cancel1Called, `is`(true))
        assertThat(cancel2Called, `is`(false))
    }

    /// test cancelling 2 chained feature, when `cancel` is called while the 2nd future is pending
    func testCancel2nd() {
        var cancel1Called = false
        var cancel2Called = false
        async { promise in
            promise.registerCancel({ cancel1Called = true })
            promise.fulfill(with: ())
            }.then { (promise: Promise<Void, Error>, _: Void) in
                promise.registerCancel({ cancel2Called = true })
            }.cancel()
        assertThat(cancel1Called, `is`(false))
        assertThat(cancel2Called, `is`(true))
    }

    /// Test `await` on a specific queue
    func testQueue() {
        let queue = DispatchQueue(label: "test")

        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.await(on: queue ) { result in
                dispatchPrecondition(condition: .onQueue(queue))
                assertThat(try? result.get(), presentAnd(`is`("X")))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// Test dispatching future on a specific queue
    func testDispatch() {
        let queue = DispatchQueue(label: "test")

        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.dispatch(on: queue).await { result in
                dispatchPrecondition(condition: .onQueue(queue))
                assertThat(try? result.get(), presentAnd(`is`("X")))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
