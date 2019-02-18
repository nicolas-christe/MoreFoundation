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
        let urlBase = URL(string: "http://www.nixit.co.uk")!

        let url = urlBase.appending(queryParams: ["p1": "1", "p2": "2", "p3": nil])

        let queryParams = url.flatQueryParams
        assertThat(queryParams, presentAnd(allOf(
            hasEntry("p1", "1"),
            hasEntry("p2", "2"),
            hasEntry("p3", nil))))
    }

    func testGetQueryParams() {
        let urlBase = URL(string: "http://www.nixit.co.uk")!

        let url = urlBase.appending(queryParams: ["p1": ["1", "2"], "p3": []])

        let queryParams = url.queryParams
        assertThat(queryParams, presentAnd(allOf(
            hasEntry("p1", ["1", "2"]),
            hasEntry("p3", []))))
    }
}
