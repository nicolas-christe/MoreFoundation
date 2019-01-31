/// Copyright (c) 2017-18 Nicolas Christe
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

protocol Named {
    func getName() -> String
}

func isNamed(_ name: String) -> Matcher<Named> {
    return Matcher("named") { $0.getName() == name }
}

// A single class simple service
class SimpleService: ContainerService, Named {
    static var descriptor = Container.ServiceDescriptor<SimpleService>()
    func getName() -> String {
        return "SimpleService"
    }
}

// Protocol based service
protocol FullServiceProtocol: Named {
    func getName() -> String
}
let fullServiceDescriptor = Container.ServiceDescriptor<FullServiceProtocol>()

// An implementation of FullServiceProtocol
class FullService: FullServiceProtocol, ContainerService {
    static var descriptor = fullServiceDescriptor
    func getName() -> String {
        return "FullService"
    }
}

// An aternate implementation of FullServiceProtocol
class AlternateFullService: FullServiceProtocol, ContainerService {
    static var descriptor = fullServiceDescriptor
    func getName() -> String {
        return "AlternateFullService"
    }
}

// A service dependent on an other service
class DependentService: ContainerService, Named {
    static var descriptor = Container.ServiceDescriptor<DependentService>()
    let fullService: FullServiceProtocol
    init(container: Container) {
        self.fullService = container.getService(descriptor: fullServiceDescriptor)
    }
    func getName() -> String {
        return "DependentService-\(fullService.getName())"
    }
}

class DependencyLoopService1: ContainerService {
    static var descriptor = Container.ServiceDescriptor<DependencyLoopService1>()
    init(container: Container) {
        _ = container.getService(descriptor: DependencyLoopService2.descriptor)
    }
}

class DependencyLoopService2: ContainerService {
    static var descriptor = Container.ServiceDescriptor<DependencyLoopService2>()
    init(container: Container) {
        _ = container.getService(descriptor: DependencyLoopService1.descriptor)
    }
}

class WrongService: ContainerService {
    static var descriptor = Container.ServiceDescriptor<SimpleService>()
}

class ContainerTests: XCTestCase {
    var container: Container!

    override func setUp() {
        container = Container()
    }

    override func tearDown() {
        container = nil
    }

    func testSimpleService() throws {
        container.register { _ in
            SimpleService()
        }
        // get the SimpleService
        let service = container.getService(descriptor: SimpleService.descriptor)
        assertThat(service, isNamed("SimpleService"))
        // get the SimpleService a 2nd time, ensure it's the same instance
        let service2 = container.getService(descriptor: SimpleService.descriptor)
        XCTAssertTrue(service === service2)
    }

    func testFullService() throws {
        container.register { _ in
            FullService()
        }
        let service = container.getService(descriptor: fullServiceDescriptor)
        assertThat(service, isNamed("FullService"))
    }

    func testAlternaleFullService() throws {
        container.register { _ in
            AlternateFullService()
        }
        let service = container.getService(descriptor: fullServiceDescriptor)
        assertThat(service, isNamed("AlternateFullService"))
    }

    func testDependentService() throws {
        container.register { container in
            DependentService(container: container)
        }
        container.register { _ in
            FullService()
        }
        let service = container.getService(descriptor: DependentService.descriptor)
        assertThat(service, isNamed("DependentService-FullService"))
    }

    func testServiceNotFound() {
        let expectation = self.expectation(description: "expectingFatal")
        fatalInterceptor = { _ in
            expectation.fulfill()
            never()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = self.container.getService(descriptor: SimpleService.descriptor)
        }
        waitForExpectations(timeout: 5)
        fatalInterceptor = nil
    }

    func testDuplicateRegister() {
        let expectation = self.expectation(description: "expectingFatal")
        fatalInterceptor = { _ in
            expectation.fulfill()
            never()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.container.register { _ in
                SimpleService()
            }
            self.container.register { _ in
                SimpleService()
            }
        }
        waitForExpectations(timeout: 5)
        fatalInterceptor = nil
    }

    func testWrongService() throws {
        let expectation = self.expectation(description: "expectingFatal")
        fatalInterceptor = { _ in
            expectation.fulfill()
            never()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.container.register { _ in
                WrongService()
            }
            _ = self.container.getService(descriptor: WrongService.descriptor)
        }
        waitForExpectations(timeout: 5)
        fatalInterceptor = nil
    }

    func testDependencyLoop() throws {
        let expectation = self.expectation(description: "expectingFatal")
        fatalInterceptor = { _ in
            expectation.fulfill()
            never()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.container.register { container in
                DependencyLoopService1(container: container)
            }
            self.container.register { container in
                DependencyLoopService2(container: container)
            }
            _ = self.container.getService(descriptor: DependencyLoopService1.descriptor)
        }
        waitForExpectations(timeout: 5)
        fatalInterceptor = nil
    }
}
