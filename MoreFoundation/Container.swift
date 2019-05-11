/// Copyright (c) 2017-19 Nicolas Christe
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

import Foundation

/// A Service that can be registered in a `Container`
public protocol ContainerService: AnyObject {
    /// Type of the service
    associatedtype ServiceClass = Self
    /// service descriptor
    static var descriptor: Container.ServiceDescriptor<ServiceClass> { get }
}

/// A simple dependency Container.
public class Container {

    /// Service unique identifier type
    typealias ServiceUid = ObjectIdentifier
    /// Service descriptor
    /// - parameter Service: service type
    public class ServiceDescriptor<Service> {
        /// Service uid
        fileprivate private(set) var serviceUid: ServiceUid!
        /// Constructor
        public init() {
            serviceUid = ServiceUid(self)
        }
    }

    /// A reference on a service or a service factory
    private enum ServiceRef {
        /// Ref on a service instance
        case instance(AnyObject)
        /// Ref on a service factory
        case factory((Container) -> AnyObject)
        /// Transitive state: service is currently instantiated. Used for dependency loop detection
        case instantiating
    }

    /// Map of registered services
    private var services = [ServiceUid: ServiceRef]()
    /// Queue in with services are instanced
    private let queue: DispatchQueue
    /// Queue identifier
    private let dispatchSpecificKey = DispatchSpecificKey<ObjectIdentifier>()

    /// Constructor
    public init(queue: DispatchQueue = DispatchQueue(label: "Container")) {
        self.queue = queue
        queue.setSpecific(key: dispatchSpecificKey, value: ObjectIdentifier(self))
    }

    deinit {
        queue.setSpecific(key: dispatchSpecificKey, value: nil)
    }

    /// Register a service
    ///
    /// - Parameters:
    ///   - factory: factory to create the service
    ///   - container: self
    ///   - service: service to register
    public func register<S: ContainerService>(factory: @escaping (_ container: Container) -> S) {
        guard services[S.descriptor.serviceUid] == nil else {
            fatal("Service Already registered")
        }
        services[S.descriptor.serviceUid] = .factory(factory)
    }

    /// Get a service. Service is instantiated if required.
    ///
    /// - Parameter descriptor: descriptor of the service to get
    /// - Returns: Service instance if found
    public func getService<S>(descriptor: ServiceDescriptor<S>) -> S {
        if DispatchQueue.getSpecific(key: dispatchSpecificKey) == ObjectIdentifier(self) {
            return queue.sync {
                self.getServiceLocked(descriptor: descriptor)
            }
        } else {
            return getServiceLocked(descriptor: descriptor)
        }
    }

    /// Get a service. Service is instantiated if required. Run in the container queue.
    ///
    /// - Parameter descriptor: descriptor of the service to get
    /// - Returns: Service instance if found
    private func getServiceLocked<S>(descriptor: ServiceDescriptor<S>) -> S {
        if let serviceRef = services[descriptor.serviceUid] {
            switch serviceRef {
            case .instance(let service):
                // swiftlint:disable:next force_cast
                return service as! S
            case .factory(let factory):
                return create(descriptor: descriptor, factory: factory)
            case .instantiating:
                fatal("Container dependency loop")
            }
        }
        fatal("Container service \(descriptor) not found")
    }

    /// Instantiate a service
    ///
    /// - Parameters:
    ///   - descriptor: descriptor of the service to create
    ///   - factory: service factory closure
    ///   - container: self
    /// - Returns: created service service
    private func create<S>(descriptor: ServiceDescriptor<S>, factory: (_ container: Container) -> AnyObject) -> S {
        services[descriptor.serviceUid] = .instantiating
        if let service = factory(self) as? S {
            services[descriptor.serviceUid] = .instance(service as AnyObject)
            return service
        }
        fatal("Container service \(descriptor) invalid type")
    }
}
