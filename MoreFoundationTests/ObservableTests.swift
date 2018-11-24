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

class ObservableTests: XCTestCase {

    /// Test `willBeObserved` and `wasObserved` callbacks
    func testwillBeObservedWasObserved() {
        let bag1 = DisposeBag()
        let bag2 = DisposeBag()

        var willBeObservedCnt = 0
        var wasObserved = 0

        let observable = Observable<String>(
            willBeObserved: { willBeObservedCnt += 1},
            wasObserved: { wasObserved += 1} )

        observable.on(.value("1"))
        assertThat(willBeObservedCnt, `is`(0))
        assertThat(wasObserved, `is`(0))

        observable.subscribe({ _ in}).disposed(by: bag1)
        assertThat(willBeObservedCnt, `is`(1))
        assertThat(wasObserved, `is`(0))

        observable.subscribe({ _ in}).disposed(by: bag2)
        assertThat(willBeObservedCnt, `is`(1))
        assertThat(wasObserved, `is`(0))

        bag1.dispose()
        assertThat(willBeObservedCnt, `is`(1))
        assertThat(wasObserved, `is`(0))

        bag2.dispose()
        assertThat(willBeObservedCnt, `is`(1))
        assertThat(wasObserved, `is`(1))
    }

    /// Test subcribe
    func testSubscribe() {
        let bag1 = DisposeBag()
        let bag2 = DisposeBag()

        let observable = Observable<String>()

        var handler1Events = [Event<String>]()
        var handler2Events = [Event<String>]()

        // check observer is notified
        observable.subscribe { handler1Events.append($0) }.disposed(by: bag1)
        observable.on(.value("X"))
        assertThat(handler1Events, contains(.value("X")))

        // check 2nd observer is also notified
        observable.subscribe({handler2Events.append($0)}).disposed(by: bag2)
        observable.on(.value("Y"))
        assertThat(handler1Events, contains(.value("X"), .value("Y")))
        assertThat(handler2Events, contains(.value("Y")))

        // check that unregisted observers are not notified
        bag1.dispose()
        observable.on(.value("Z"))
        assertThat(handler1Events, contains(.value("X"), .value("Y")))
        assertThat(handler2Events, contains(.value("Y"), .value("Z")))
    }

    // test ".map()" function
    func testMap() {
        let bag = DisposeBag()
        let observable = Observable<String>()

        var handlerEvents = [Event<Int>]()

        observable.map({ $0.count }).subscribe({ handlerEvents.append($0) }).disposed(by: bag)

        observable.on(.value("123"))
        assertThat(handlerEvents, contains(.value(3)))
    }

    func testVariable() {
        let bag = DisposeBag()
        let variable = Variable<String>(value: "X")

        var handlerEvents = [Event<String>]()
        variable.subscribe({ handlerEvents.append($0) }).disposed(by: bag)
        // ensure that initial value is notified
        assertThat(handlerEvents, contains(.value("X")))

        variable.value = "Y"
        assertThat(handlerEvents, contains(.value("X"), .value("Y")))
    }

    func testValue() {
        let bag = DisposeBag()
        let observable = Observable<String>()

        let value = Value<String>(source: observable)
        assertThat(value.value, `is`(nilValue()))

        observable.on(.value("X"))
        assertThat(value.value, presentAnd(`is`("X")))

        var observedValues = [String?]()
        value.subscribe(.onValue { observedValues.append($0) }).disposed(by: bag)
        assertThat(observedValues, contains("X"))

        observable.on(.value("Y"))
        assertThat(value.value, presentAnd(`is`("Y")))
        assertThat(observedValues, contains("X", "Y"))
   }
}
