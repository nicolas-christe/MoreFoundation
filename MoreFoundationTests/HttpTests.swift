/// Copyright (c) 2019 Nicolas Christe
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

class HttpTests: XCTestCase {

    func testGetFlatQueryParams() {
        let urlBase = URL(staticString: "http://www.nixit.co.uk")

        let url = urlBase.appending(queryParams: ["p1": "1", "p2": "2", "p3": nil])

        let queryParams = url.flatQueryParams
        assertThat(queryParams, presentAnd(allOf(
            hasEntry("p1", "1"),
            hasEntry("p2", "2"),
            hasEntry("p3", nil))))
    }

    func testGetQueryParams() {
        let urlBase = URL(staticString: "http://www.nixit.co.uk")

        let url = urlBase.appending(queryParams: ["p1": ["1", "2"], "p3": []])

        let queryParams = url.queryParams
        assertThat(queryParams, presentAnd(allOf(
            hasEntry("p1", ["1", "2"]),
            hasEntry("p3", []))))
    }

    func testHttpDataTaskSuccess() {
        let expectation = self.expectation(description: "success")
        let url = URL(staticString: "https://www.nixit.co.uk/tests")
        let session = URLSessionMock().apply {
            $0.setNextResponse(
                response: HTTPURLResponse(
                    url: url, statusCode: 200, httpVersion: nil, headerFields: ["header": "value"])!,
                data: "data".data(using: .utf8)!)
        }

        async {
            session.httpDataTask(request: URLRequest(url: url), promise: $0)
            }.done(on: DispatchQueue.main) { statusCode, headers, body in
                assertThat(statusCode, `is`(200))
                assertThat(headers, `is`(["header": "value"]))
                assertThat(body, `is`("data".data(using: .utf8)!))
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testHttpDataTaskSuccessAdditionalAcceptableStatusCodes() {
        let expectation = self.expectation(description: "success")
        let url = URL(staticString: "https://www.nixit.co.uk/tests")
        let session = URLSessionMock().apply {
            $0.setNextResponse(
                response: HTTPURLResponse(
                    url: url, statusCode: 302, httpVersion: nil, headerFields: ["header": "value"])!,
                data: "data".data(using: .utf8)!)
        }

        async {
            session.httpDataTask(request: URLRequest(url: url), additionalAcceptableStatusCodes: [302], promise: $0)
            }.done(on: DispatchQueue.main) { statusCode, headers, body in
                assertThat(statusCode, `is`(302))
                assertThat(headers, `is`(["header": "value"]))
                assertThat(body, `is`("data".data(using: .utf8)!))
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testHttpDataTaskHttpError() {
        let expectation = self.expectation(description: "error")
        let url = URL(staticString: "https://www.nixit.co.uk/tests")
        let session = URLSessionMock().apply {
            $0.setNextResponse(
                response: HTTPURLResponse(
                    url: url, statusCode: 500, httpVersion: nil, headerFields: ["header": "value"])!,
                data: "data".data(using: .utf8)!)
        }

        async {
            session.httpDataTask(request: URLRequest(url: url), promise: $0)
            }.catch { error in
                assertThat(error as? HttpError, presentAnd(`is`(HttpError.error(statusCode: 500))))
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testHttpDataTaskError() {
        let expectation = self.expectation(description: "error")
        let url = URL(staticString: "https://www.nixit.co.uk/tests")
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil)
        let session = URLSessionMock().apply {
            $0.setNextResponse(error: networkError)
        }

        async {
            session.httpDataTask(request: URLRequest(url: url), promise: $0)
            }.catch { error in
                assertThat(error as NSError, `is`(networkError))
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

}

/// A mock URL session
class URLSessionMock: URLSession {

    class DataTask: URLSessionDataTask {
        private let closure: (_ cancelled: Bool) -> Void
        private var cancelled = false

        init(closure: @escaping (_ cancelled: Bool) -> Void) {
            self.closure = closure
        }

        override func resume() {
            closure(false)
        }

        override func cancel() {
            cancelled = true
        }
    }

    private var queue = DispatchQueue(label: "URLSessionMock")
    private var response: (data: Data?, response: HTTPURLResponse?, error: Error?)?

    func setNextResponse(error: Error) {
        self.response = (data: nil, response: nil, error: error)
    }

    func setNextResponse(response: HTTPURLResponse, data: Data) {
        self.response = (data: data, response: response, error: nil)
    }

    override func dataTask(with request: URLRequest,
                           completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return DataTask { cancelled in
            self.queue.async {
                guard !cancelled else {
                    completionHandler(nil, nil,
                                      NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil))
                    return
                }
                if let response = self.response {
                    completionHandler(response.data, response.response, response.error)
                } else {
                    completionHandler(nil, nil, nil)
                }
                self.response = nil
            }
        }
    }
}
