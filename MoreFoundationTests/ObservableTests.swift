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
            wasObserved: { wasObserved += 1})

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

        var observable: Observable<String>! = Observable()

        var events1 = [Event<String>]()
        var events2 = [Event<String>]()

        // check observer is notified
        observable.subscribe { events1.append($0) }.disposed(by: bag1)
        observable.on(.value("X"))
        assertThat(events1, contains(.value("X")))

        // check 2nd observer is also notified
        observable.subscribe({events2.append($0)}).disposed(by: bag2)
        observable.on(.value("Y"))
        assertThat(events1, contains(.value("X"), .value("Y")))
        assertThat(events2, contains(.value("Y")))

        // check that unregisted observers are not notified
        bag1.dispose()
        observable.on(.value("Z"))
        assertThat(events1, contains(.value("X"), .value("Y")))
        assertThat(events2, contains(.value("Y"), .value("Z")))

        // check terminated
        observable = nil
        assertThat(events1, contains(.value("X"), .value("Y")))
        assertThat(events2, contains(.value("Y"), .value("Z"), .terminated))
    }

    func testHandlers() {
        let bag = DisposeBag()
        var observable: Observable<String>? = Observable()
        var events = [Event<String>]()
        var values = [String]()
        var terminated = 0

        observable?.subscribe(
            .onEvent { events.append($0) },
            .onValue { values.append($0) },
            .onTerminated { terminated += 1})
        .disposed(by: bag)

        assertThat(events, `is`(empty()))
        assertThat(values, `is`(empty()))
        assertThat(terminated, `is`(0))

        observable!.on(.value("X"))
        assertThat(events, contains(.value("X")))
        assertThat(values, contains("X"))
        assertThat(terminated, `is`(0))

        observable = nil
        assertThat(events, contains(.value("X"), .terminated))
        assertThat(values, contains("X"))
        assertThat(terminated, `is`(1))
    }

    // test ".map()" function
    func testMap() {
        let bag = DisposeBag()
        var observable: Observable<String>? = Observable()

        var events = [Event<Int>]()

        observable!.map({ $0.count }).subscribe({ events.append($0) }).disposed(by: bag)

        observable!.on(.value("123"))
        assertThat(events, contains(.value(3)))

        observable = nil
        assertThat(events, contains(.value(3), .terminated))
    }

    func testVariable() {
        let bag = DisposeBag()
        let variable = Variable<String>(value: "X")

        var events = [Event<String>]()
        variable.subscribe({ events.append($0) }).disposed(by: bag)
        // ensure that initial value is notified
        assertThat(events, contains(.value("X")))

        variable.value = "Y"
        assertThat(events, contains(.value("X"), .value("Y")))
    }

    func testValue() {
        let bag = DisposeBag()
        var observable: Observable<String>? = Observable()

        let value = Value<String>(source: observable!)
        assertThat(value.value, `is`(nilValue()))

        observable!.on(.value("X"))
        assertThat(value.value, presentAnd(`is`("X")))

        var events = [Event<String?>]()
        value.subscribe({ events.append($0) }).disposed(by: bag)
        assertThat(events, contains(.value("X")))

        observable!.on(.value("Y"))
        assertThat(value.value, presentAnd(`is`("Y")))
        assertThat(events, contains(.value("X"), .value("Y")))

        observable = nil
        assertThat(value.value, `is`(nilValue()))
        assertThat(events, contains(.value("X"), .value("Y"), .terminated))
   }
}
