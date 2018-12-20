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

import XCTest
import MoreFoundation
import Hamcrest

private enum Error: Swift.Error {
    case fail
}

private func asyncFunc(promise: Promise<String>, val: String?) {
    DispatchQueue.main.async {
        if let val = val {
            promise.fulfill(with: val)
        } else {
            promise.reject(with: Error.fail)
        }
    }
}

class FutureTests: XCTestCase {

    func testSingleFuture() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.await { result in
                assertThat(try? result.get(), presentAnd(`is`("X")))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAwaitAlreadyCompleted() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            promise.fulfill(with: "X")
            }.await { result in
                assertThat(try? result.get(), presentAnd(`is`("X")))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testDone() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.done { str in
                assertThat(str, `is`("X"))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCatch() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.catch { error in
                assertThat(error as? Error, `is`(Error.fail))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testFinally() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.finally {
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

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

    func testThen1stFail() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: nil)
            }.then { promise, value in
                asyncFunc(promise: promise, val: value + "Y")
            }.catch { error in
                assertThat(error as? Error, `is`(Error.fail))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testThen2ndFail() {
        let expectation = XCTestExpectation(description: "promise is fulfilled")
        async { promise in
            asyncFunc(promise: promise, val: "X")
            }.then { promise, _ in
                asyncFunc(promise: promise, val: nil)
            }.catch { error in
                assertThat(error as? Error, `is`(Error.fail))
                expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCancel1st() {
        var cancel1Called = false
        var cancel2Called = false
        async { promise in
            promise.registerCancel({ cancel1Called = true })
            }.then { (promise: Promise<Void>, _: Void) in
                promise.registerCancel({ cancel2Called = true })
            }.cancel()
        assertThat(cancel1Called, `is`(true))
        assertThat(cancel2Called, `is`(false))
    }

    func testCancel2nd() {
        var cancel1Called = false
        var cancel2Called = false
        async { promise in
            promise.registerCancel({ cancel1Called = true })
            promise.fulfill(with: ())
            }.then { (promise: Promise<Void>, _: Void) in
                promise.registerCancel({ cancel2Called = true })
            }.cancel()
        assertThat(cancel1Called, `is`(false))
        assertThat(cancel2Called, `is`(true))
    }

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
}
