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

// swiftlint:disable nesting
class ApplyTests: XCTestCase {

    func testApplyOnObject() {
        class MyClass: Applicable {
            var val = 0
        }
        let myObj = MyClass().apply {
            $0.val = 42
        }
        assertThat(myObj.val, `is`(42))
    }

    func testApplyOnStruct() {
        struct MyStruct: Applicable {
            var val = 0
        }
        let myObj = MyStruct().apply {
            $0.val = 42
        }
        assertThat(myObj.val, `is`(42))
    }

    func testApplyOnNSObject() {
        let dateFormatter = DateFormatter().apply {
            assertThat($0.dateStyle, `is`(.none))
            $0.dateStyle = .long
        }
        assertThat(dateFormatter.dateStyle, `is`(.long))
    }
}
