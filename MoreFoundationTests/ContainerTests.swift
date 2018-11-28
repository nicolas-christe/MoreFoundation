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
class SimpleService: Service, Named {
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
class FullService: FullServiceProtocol, Service {
    static var descriptor = fullServiceDescriptor
    func getName() -> String {
        return "FullService"
    }
}

// An aternate implementation of FullServiceProtocol
class AlternateFullService: FullServiceProtocol, Service {
    static var descriptor = fullServiceDescriptor
    func getName() -> String {
        return "AlternateFullService"
    }
}

// A service dependent on an other service
class DependentService: Service, Named {
    static var descriptor = Container.ServiceDescriptor<DependentService>()
    let fullService: FullServiceProtocol
    init(container: Container) throws {
        self.fullService = try container.getService(descriptor: fullServiceDescriptor)
    }
    func getName() -> String {
        return "DependentService-\(fullService.getName())"
    }
}

class DependencyLoopService1: Service {
    static var descriptor = Container.ServiceDescriptor<DependencyLoopService1>()
    init(container: Container) throws {
        _ = try container.getService(descriptor: DependencyLoopService2.descriptor)
    }
}

class DependencyLoopService2: Service {
    static var descriptor = Container.ServiceDescriptor<DependencyLoopService2>()
    init(container: Container) throws {
        _ = try container.getService(descriptor: DependencyLoopService1.descriptor)
    }
}

class FailingService: Service {
    static var descriptor = Container.ServiceDescriptor<FailingService>()
    enum Err: Error {
        case error
    }
    init() throws {
        throw Err.error
    }
}

class WrongService: Service {
    static var descriptor = Container.ServiceDescriptor<FailingService>()
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
        try container.register { _ in
            return SimpleService()
        }
        // get the SimpleService
        let service = try? container.getService(descriptor: SimpleService.descriptor)
        assertThat(service, presentAnd(isNamed("SimpleService")))
        // get the SimpleService a 2nd time, ensure it's the same instance
        let service2 = try? container.getService(descriptor: SimpleService.descriptor)
        XCTAssertTrue(service === service2)
    }

    func testFullService() throws {
        try container.register { _ in
            return FullService()
        }
        let service = try? container.getService(descriptor: fullServiceDescriptor)
        assertThat(service, presentAnd(isNamed("FullService")))
    }

    func testAlternaleFullService() throws {
        try container.register { _ in
            return AlternateFullService()
        }
        let service = try? container.getService(descriptor: fullServiceDescriptor)
        assertThat(service, presentAnd(isNamed("AlternateFullService")))
    }

    func testDependentService() throws {
        try container.register { container in
            return try DependentService(container: container)
        }
        try container.register { _ in
            return FullService()
        }
        let service = try? container.getService(descriptor: DependentService.descriptor)
        assertThat(service, presentAnd(isNamed("DependentService-FullService")))
    }

    func testServiceNotFound() throws {
        do {
            _ = try container.getService(descriptor: SimpleService.descriptor)
            XCTFail("must have thrown")
        } catch Container.ContainerError.notFound {
        } catch let err {
            XCTFail("\(err)")
        }
    }

    func testDuplicateRegister() throws {
        do {
            try container.register { _ in
                return SimpleService()
            }
            try container.register { _ in
                return SimpleService()
            }
            XCTFail("must have thrown")
        } catch Container.ContainerError.alreadyRegistred {
        } catch let err {
            XCTFail("\(err)")
        }
    }

    func testInstantiateFailure() throws {
        try container.register { _ in
            return try FailingService()
        }
        do {
            _ = try container.getService(descriptor: FailingService.descriptor)
            XCTFail("must have thrown")
        } catch Container.ContainerError.instantiationError {
        } catch let err {
            XCTFail("\(err)")
        }
    }

    func testWrongService() throws {
        try container.register { _ in
            return WrongService()
        }
        do {
            _ = try container.getService(descriptor: WrongService.descriptor)
            XCTFail("must have thrown")
        } catch Container.ContainerError.wrongServiceDefinition {
        } catch let err {
            XCTFail("\(err)")
        }
    }

    func testDependencyLoop() throws {
        try container.register { container in
            return try DependencyLoopService1(container: container)
        }
        try container.register { container in
            return try DependencyLoopService2(container: container)
        }
        do {
            _ = try container.getService(descriptor: DependencyLoopService1.descriptor)
            XCTFail("must have thrown")
        } catch Container.ContainerError.dependencyLoop {
        } catch let err {
            XCTFail("\(err)")
        }
    }
}
