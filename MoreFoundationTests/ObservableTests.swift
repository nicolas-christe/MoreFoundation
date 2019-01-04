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
    func testWillBeObservedWasObserved() {
        let bag1 = DisposeBag()
        let bag2 = DisposeBag()

        var willBeObservedCnt = 0
        var wasObserved = 0

        let observable = Observable<String>(
            willBeObserved: { willBeObservedCnt += 1 },
            wasObserved: { wasObserved += 1 })

        observable.onNext("1")
        assertThat(willBeObservedCnt, `is`(0))
        assertThat(wasObserved, `is`(0))

        observable.subscribe({ _ in }).disposed(by: bag1)
        assertThat(willBeObservedCnt, `is`(1))
        assertThat(wasObserved, `is`(0))

        observable.subscribe({ _ in }).disposed(by: bag2)
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
        observable.onNext("X")
        assertThat(events1, contains(.next("X")))

        // check 2nd observer is also notified
        observable.subscribe({ events2.append($0) }).disposed(by: bag2)
        observable.onNext("Y")
        assertThat(events1, contains(.next("X"), .next("Y")))
        assertThat(events2, contains(.next("Y")))

        // check that unregisted observers are not notified
        bag1.dispose()
        observable.onNext("Z")
        assertThat(events1, contains(.next("X"), .next("Y")))
        assertThat(events2, contains(.next("Y"), .next("Z")))

        // check observable is terminated on deinit
        observable = nil
        assertThat(events1, contains(.next("X"), .next("Y")))
        assertThat(events2, contains(.next("Y"), .next("Z"), .terminated))
    }

    func testSubscribeHandlers() {
        let bag = DisposeBag()
        let observable = Observable<String>()
        var events = [Event<String>]()
        var values = [String]()
        var terminated = 0

        observable.subscribe(
            .onEvent { events.append($0) },
            .onNext { values.append($0) },
            .onTerminated { terminated += 1 })
        .disposed(by: bag)

        assertThat(events, `is`(empty()))
        assertThat(values, `is`(empty()))
        assertThat(terminated, `is`(0))

        observable.onNext("X")
        assertThat(events, contains(.next("X")))
        assertThat(values, contains("X"))
        assertThat(terminated, `is`(0))

        observable.onTerminated()
        assertThat(events, contains(.next("X"), .terminated))
        assertThat(values, contains("X"))
        assertThat(terminated, `is`(1))
    }

    func testSubscribeOnTerminatedObservable() {
        let bag = DisposeBag()
        let observable = Observable<String>()
        var events = [Event<String>]()

        observable.onTerminated()
        observable.subscribe({ events.append($0) }).disposed(by: bag)
        assertThat(events, contains(.terminated))
    }

    func testOnNextOnTerminatedObservable() {
        let expectation = self.expectation(description: "expectingFatal")
        fatalInterceptor = { _ in
            expectation.fulfill()
            never()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let observable = Observable<String>()
            observable.onTerminated()
            observable.onNext("X")
        }
        waitForExpectations(timeout: 1)
        fatalInterceptor = nil
    }

    // test ".map()" function
    func testMap() {
        let bag = DisposeBag()
        let observable = Observable<String>()

        var events = [Event<Int>]()

        observable.map({ $0.count }).subscribe({ events.append($0) }).disposed(by: bag)

        observable.onNext("123")
        assertThat(events, contains(.next(3)))

        observable.onTerminated()
        assertThat(events, contains(.next(3), .terminated))
    }

    func testFilter() {
        let bag = DisposeBag()
        let observable = Observable<String>()

        var events = [Event<String>]()

        observable.filter({ $0.count > 1 }).subscribe({ events.append($0) }).disposed(by: bag)

        observable.onNext("XX")
        assertThat(events, contains(.next("XX")))

        observable.onNext("Y")
        assertThat(events, contains(.next("XX")))

        observable.onTerminated()
        assertThat(events, contains(.next("XX"), .terminated))
    }

    func testVariable() {
        let bag = DisposeBag()
        let variable = Variable<String>("X")

        var events = [Event<String>]()
        variable.subscribe({ events.append($0) }).disposed(by: bag)
        // ensure that initial value is notified
        assertThat(events, contains(.next("X")))

        variable.onNext("Y")
        assertThat(events, contains(.next("X"), .next("Y")))
    }

    func testValue() {
        let bag = DisposeBag()
        let observable = Observable<String>()

        let value = Value("I")
        assertThat(value.value, presentAnd(`is`("I")))

        value.bind(to: observable)
        assertThat(value.value, presentAnd(`is`("I")))

        observable.onNext("X")
        assertThat(value.value, presentAnd(`is`("X")))

        var events = [Event<String>]()
        value.subscribe({ events.append($0) }).disposed(by: bag)
        assertThat(events, contains(.next("X")))

        observable.onNext("Y")
        assertThat(value.value, presentAnd(`is`("Y")))
        assertThat(events, contains(.next("X"), .next("Y")))

        observable.onTerminated()
        assertThat(events, contains(.next("X"), .next("Y"), .terminated))
    }

    func testValueMapVariable() {
        let variable = Variable("X")
        let value = Value("")

        value.bind(to: variable.map { $0+"X" })
        assertThat(value.value, presentAnd(`is`("XX")))
    }

    func testValueObserveValue() {
        let variable = Variable("X")
        let value1 = Value("")
        let value2 = Value("")

        value1.bind(to: variable.map { $0+"X" })
        value2.bind(to: value1.map { $0+"X" })
        assertThat(value1.value, presentAnd(`is`("XX")))
        assertThat(value2.value, presentAnd(`is`("XXX")))
    }

    func testEventStore() throws {
        let observable = Observable<String>()
        let store = observable.subscribeStore()

        assertThat(store.peek(), `is`(nilValue()))

        observable.onNext("X")
        assertThat(try store.pop().value, presentAnd(`is`("X")))

        observable.onNext("Y")
        assertThat(try store.popValue(), presentAnd(`is`("Y")))

        observable.onTerminated()
        try store.popTerminated()
    }
}
